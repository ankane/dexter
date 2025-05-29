module Dexter
  class Indexer
    include Logging

    def initialize(**options)
      @create = options[:create]
      @tablespace = options[:tablespace]
      @log_level = options[:log_level]
      @exclude_tables = options[:exclude]
      @include_tables = Array(options[:include].split(",")) if options[:include]
      @log_sql = options[:log_sql]
      @log_explain = options[:log_explain]
      @min_time = options[:min_time] || 0
      @min_calls = options[:min_calls] || 0
      @analyze = options[:analyze]
      @min_cost_savings_pct = options[:min_cost_savings_pct].to_i
      @options = options
      @mutex = Mutex.new

      if server_version_num < 130000
        raise Dexter::Abort, "This version of Dexter requires Postgres 13+"
      end

      check_extension

      execute("SET lock_timeout = '5s'")
    end

    def process_stat_statements
      queries = stat_statements.map { |q| Query.new(q) }.sort_by(&:fingerprint).group_by(&:fingerprint).map { |_, v| v.first }
      log "Processing #{queries.size} new query fingerprints"
      process_queries(queries)
    end

    def process_queries(queries)
      # reset hypothetical indexes
      reset_hypothetical_indexes

      tables = Set.new(database_tables + materialized_views)

      # map tables without schema to schema
      no_schema_tables = {}
      search_path_index = Hash[search_path.map.with_index.to_a]
      tables.group_by { |t| t.split(".")[-1] }.each do |group, t2|
        no_schema_tables[group] = t2.sort_by { |t| [search_path_index[t.split(".")[0]] || 1000000, t] }[0]
      end

      # add tables from views
      view_tables = database_view_tables
      view_tables.each do |v, vt|
        view_tables[v] = vt.map { |t| no_schema_tables[t] || t }
      end

      # fully resolve tables
      # make sure no views in result
      view_tables.each do |v, vt|
        view_tables[v] = vt.flat_map { |t| view_tables[t] || [t] }.uniq
      end

      # filter queries from other databases and system tables
      queries.each do |query|
        # add schema to table if needed
        query.tables = query.tables.map { |t| no_schema_tables[t] || t }

        # substitute view tables
        new_tables = query.tables.flat_map { |t| view_tables[t] || [t] }.uniq
        query.tables_from_views = new_tables - query.tables
        query.tables = new_tables

        # check for missing tables
        query.missing_tables = !query.tables.all? { |t| tables.include?(t) }
      end
      candidate_queries = queries.reject(&:missing_tables)

      # set tables
      tables = Set.new(candidate_queries.flat_map(&:tables))

      # must come after missing tables set
      if @include_tables
        include_set = Set.new(@include_tables)
        tables.keep_if { |t| include_set.include?(t) || include_set.include?(t.split(".")[-1]) }
      end

      if @exclude_tables.any?
        exclude_set = Set.new(@exclude_tables)
        tables.delete_if { |t| exclude_set.include?(t) || exclude_set.include?(t.split(".")[-1]) }
      end

      # remove system tables
      tables.delete_if { |t| t.start_with?("information_schema.", "pg_catalog.") }

      candidate_queries.each do |query|
        query.candidate_tables = query.tables.select { |t| tables.include?(t) }
      end
      candidate_queries.select! { |q| q.candidate_tables.any? }

      if tables.any?
        # analyze tables if needed
        analyze_tables(tables) if @analyze || @log_level == "debug2"

        # get initial costs for queries
        calculate_plan(candidate_queries)
        candidate_queries.select! { |q| q.plans.any? && q.high_cost? }

        # find columns
        # TODO resolve possible tables
        # TODO calculate all possible indexes for query
        candidate_queries.each do |query|
          log "Finding columns: #{query.statement}" if @log_level == "debug3"
          begin
            find_columns(query.tree).each do |col|
              last_col = col["fields"].last
              if last_col["String"]
                query.columns << last_col["String"]["sval"]
              end
            end
          rescue JSON::NestingError
            if @log_level.start_with?("debug")
              log colorize("ERROR: Cannot get columns", :red)
            end
          end
        end

        # TODO sort batches
        # TODO limit batches to certain number of hypothetical indexes
        # create hypothetical indexes and explain queries
        # process in batches to prevent "hypopg: not more oid available" error
        # https://hypopg.readthedocs.io/en/rel1_stable/usage.html#configuration
        candidate_queries.each_slice(500) do |batch|
          create_hypothetical_indexes(batch)
        end
      end

      # see if new indexes were used and meet bar
      new_indexes = determine_indexes(queries, tables)

      # display and create new indexes
      show_and_create_indexes(new_indexes, queries)
    end

    private

    def check_extension
      extension = execute("SELECT installed_version FROM pg_available_extensions WHERE name = 'hypopg'").first

      if extension.nil?
        raise Dexter::Abort, "Install HypoPG first: https://github.com/ankane/dexter#installation"
      end

      if extension["installed_version"].nil?
        if @options[:enable_hypopg]
          execute("CREATE EXTENSION hypopg")
        else
          raise Dexter::Abort, "Run `CREATE EXTENSION hypopg` or pass --enable-hypopg"
        end
      end
    end

    def reset_hypothetical_indexes
      execute("SELECT hypopg_reset()")
    end

    def analyze_tables(tables)
      tables = tables.to_a.sort

      query = <<~SQL
        SELECT
          schemaname || '.' || relname AS table,
          last_analyze,
          last_autoanalyze
        FROM
          pg_stat_user_tables
        WHERE
          schemaname || '.' || relname IN (#{tables.size.times.map { |i| "$#{i + 1}" }.join(", ")})
      SQL
      analyze_stats = execute(query, params: tables.to_a)

      last_analyzed = {}
      analyze_stats.each do |stats|
        last_analyzed[stats["table"]] = Time.parse(stats["last_analyze"]) if stats["last_analyze"]
      end

      tables.each do |table|
        la = last_analyzed[table]

        if @log_level == "debug2"
          time_str = la ? la.iso8601 : "Unknown"
          log "Last analyze: #{table} : #{time_str}"
        end

        if @analyze && (!la || la < Time.now - 3600)
          statement = "ANALYZE #{quote_ident(table)}"
          log "Running analyze: #{statement}"
          execute(statement)
        end
      end
    end

    def calculate_plan(queries)
      queries.each do |query|
        if @log_explain
          puts "Explaining query"
          puts
        end
        begin
          query.plans << plan(query.statement)
        rescue PG::Error, JSON::NestingError => e
          if @log_explain
            log e.message
          end
        end
        puts if @log_explain
      end
    end

    def create_hypothetical_indexes(queries)
      candidates = {}

      reset_hypothetical_indexes

      # filter tables for performance
      tables = Set.new(queries.flat_map(&:tables))
      tables_from_views = Set.new(queries.flat_map(&:tables_from_views))
      possible_columns = Set.new(queries.flat_map(&:columns))

      # create hypothetical indexes
      # use all columns in tables from views
      columns_by_table = columns(tables).select { |c| possible_columns.include?(c[:column]) || tables_from_views.include?(c[:table]) }.group_by { |c| c[:table] }

      # create single column indexes
      create_hypothetical_indexes_helper(columns_by_table, 1, candidates)

      # get next round of costs
      calculate_plan(queries)

      # create multicolumn indexes
      create_hypothetical_indexes_helper(columns_by_table, 2, candidates)

      # get next round of costs
      calculate_plan(queries)

      queries.each do |query|
        query.candidates = candidates
      end
    end

    def find_columns(plan)
      plan = JSON.parse(plan.to_json, max_nesting: 1000)
      find_by_key(plan, "ColumnRef")
    end

    def find_indexes(plan)
      find_by_key(plan, "Index Name")
    end

    def find_by_key(plan, key)
      result = []
      queue = [plan]
      while queue.any?
        node = queue.pop
        case node
        when Hash
          node.each do |k, v|
            if k == key
              result << v
            elsif !v.nil?
              queue << v
            end
          end
        when Array
          queue.concat(node)
        end
      end
      result
    end

    def hypo_indexes_from_plan(index_name_to_columns, plan, index_set)
      query_indexes = []

      find_indexes(plan).uniq.sort.each do |index_name|
        col_set = index_name_to_columns[index_name]

        if col_set
          index = {
            table: col_set[0][:table],
            columns: col_set.map { |c| c[:column] }
          }

          unless index_set.include?([index[:table], index[:columns]])
            query_indexes << index
          end
        end
      end

      query_indexes
    end

    def determine_indexes(queries, tables)
      new_indexes = {}

      # filter out existing indexes
      # this must happen at end of process
      # since sometimes hypothetical indexes
      # can give lower cost than actual indexes
      index_set = Set.new
      if tables.any?
        indexes(tables).each do |index|
          if index["using"] == "btree"
            # don't add indexes that are already covered
            index_set << [index["table"], index["columns"].first(1)]
            index_set << [index["table"], index["columns"].first(2)]
          end
        end
      end

      savings_ratio = (1 - @min_cost_savings_pct / 100.0)

      queries.each do |query|
        if query.explainable? && query.high_cost?
          new_cost, new_cost2 = query.costs[1..2]

          cost_savings = new_cost < query.initial_cost * savings_ratio

          # set high bar for multicolumn indexes
          cost_savings2 = new_cost > 100 && new_cost2 < new_cost * savings_ratio

          key = cost_savings2 ? 2 : 1
          query_indexes = hypo_indexes_from_plan(query.candidates, query.plans[key], index_set)

          # likely a bad suggestion, so try single column
          if cost_savings2 && query_indexes.size > 1
            query_indexes = hypo_indexes_from_plan(query.candidates, query.plans[1], index_set)
            cost_savings2 = false
          end

          suggest_index = cost_savings || cost_savings2

          cost_savings3 = false
          new_cost3 = nil

          # if multiple indexes are found (for either single or multicolumn)
          # determine the impact of each individually
          # there may be a better single index that we're not considering
          # that didn't get picked up by pass1 or pass2
          # TODO clean this up
          # TODO suggest more than one index from this if savings are there
          if suggest_index && query_indexes.size > 1
            winning_index = nil
            winning_cost = nil
            winning_plan = nil

            query_indexes.each do |query_index|
              reset_hypothetical_indexes
              create_hypothetical_index(query_index[:table], query_index[:columns].map { |v| {column: v} })
              plan3 = plan(query.statement)
              cost3 = plan3["Total Cost"]

              if !winning_cost || cost3 < winning_cost
                winning_cost = cost3
                winning_index = query_index
                winning_plan = plan3
              end
            end

            query.plans << winning_plan

            # duplicated from above
            # TODO DRY
            use_winning =
              if cost_savings2
                new_cost > 100 && winning_cost < new_cost * savings_ratio
              else
                winning_cost < query.initial_cost * savings_ratio
              end

            query_indexes = [winning_index]
            new_cost3 = winning_cost
            query.pass3_indexes = query_indexes

            if use_winning
              cost_savings3 = true
            else
              suggest_index = false
            end
          end

          if suggest_index
            query_indexes.each do |index|
              new_indexes[index] ||= index.dup
              (new_indexes[index][:queries] ||= []) << query
            end
          end

          query.indexes = query_indexes
          query.suggest_index = suggest_index
          query.new_cost =
            if suggest_index
              cost_savings3 ? new_cost3 : (cost_savings2 ? new_cost2 : new_cost)
            else
              query.initial_cost
            end

          # TODO optimize
          if @log_level.start_with?("debug")
            query.pass1_indexes = hypo_indexes_from_plan(query.candidates, query.plans[1], index_set)
            query.pass2_indexes = hypo_indexes_from_plan(query.candidates, query.plans[2], index_set)
          end
        end
      end

      # filter out covered indexes
      covered = Set.new
      new_indexes.values.each do |index|
        if index[:columns].size > 1
          covered << [index[:table], index[:columns].first(1)]
        end
      end

      new_indexes.values.reject { |i| covered.include?([i[:table], i[:columns]]) }.sort_by(&:to_a)
    end

    def log_indexes(indexes)
      if indexes.any?
        indexes.map { |i| "#{i[:table]} (#{i[:columns].join(", ")})" }.join(", ")
      else
        "None"
      end
    end

    def show_and_create_indexes(new_indexes, queries)
      # print summary
      if new_indexes.any?
        new_indexes.each do |index|
          log colorize("Index found: #{index[:table]} (#{index[:columns].join(", ")})", :green)
        end
      else
        log "No new indexes found"
      end

      # debug info
      if @log_level.start_with?("debug")
        index_queries = new_indexes.flat_map { |i| i[:queries].sort_by(&:fingerprint) }
        if @log_level == "debug2"
          fingerprints = Set.new(index_queries.map(&:fingerprint))
          index_queries.concat(queries.reject { |q| fingerprints.include?(q.fingerprint) }.sort_by(&:fingerprint))
        end
        index_queries.each do |query|
          log "-" * 80
          log "Query #{query.fingerprint}"
          log "Total time: #{(query.total_time / 60000.0).round(1)} min, avg time: #{(query.total_time / query.calls.to_f).round} ms, calls: #{query.calls}" if query.total_time

          if query.fingerprint == "unknown"
            log "Could not parse query"
          elsif query.tables.empty?
            log "No tables"
          elsif query.missing_tables
            log "Tables not present in current database"
          elsif query.candidate_tables.empty?
            log "No candidate tables for indexes"
          elsif query.explainable? && !query.high_cost?
            log "Low initial cost: #{query.initial_cost}"
          elsif query.explainable?
            query_indexes = query.indexes || []
            log "Start: #{query.costs[0]}"
            log "Pass1: #{query.costs[1]} : #{log_indexes(query.pass1_indexes || [])}"
            log "Pass2: #{query.costs[2]} : #{log_indexes(query.pass2_indexes || [])}"
            if query.costs[3]
              log "Pass3: #{query.costs[3]} : #{log_indexes(query.pass3_indexes || [])}"
            end
            log "Final: #{query.new_cost} : #{log_indexes(query.suggest_index ? query_indexes : [])}"
            if (query.pass1_indexes.any? || query.pass2_indexes.any?) && !query.suggest_index
              log "Need #{@min_cost_savings_pct}% cost savings to suggest index"
            end
          else
            log "Could not run explain"
          end
          log
          log query.statement
          log
        end
      end

      # create
      if @create && new_indexes.any?
        # 1. create lock
        # 2. refresh existing index list
        # 3. create indexes that still don't exist
        # 4. release lock
        with_advisory_lock do
          new_indexes.each do |index|
            unless index_exists?(index)
              statement = String.new("CREATE INDEX CONCURRENTLY ON #{quote_ident(index[:table])} (#{index[:columns].map { |c| quote_ident(c) }.join(", ")})")
              statement << " TABLESPACE #{quote_ident(@tablespace)}" if @tablespace
              log "Creating index: #{statement}"
              started_at = monotonic_time
              begin
                execute(statement)
                log "Index created: #{((monotonic_time - started_at) * 1000).to_i} ms"
              rescue PG::LockNotAvailable
                log "Could not acquire lock: #{index[:table]}"
              end
            end
          end
        end
      end

      new_indexes
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def conn
      @conn ||= begin
        # set connect timeout if none set
        ENV["PGCONNECT_TIMEOUT"] ||= "3"

        if @options[:dbname].start_with?("postgres://", "postgresql://")
          config = @options[:dbname]
        else
          config = {
            host: @options[:host],
            port: @options[:port],
            dbname: @options[:dbname],
            user: @options[:username]
          }.reject { |_, value| value.to_s.empty? }
          config = config[:dbname] if config.keys == [:dbname] && config[:dbname].include?("=")
        end
        PG::Connection.new(config)
      end
    rescue PG::ConnectionBad => e
      raise Dexter::Abort, e.message
    end

    def execute(query, pretty: true, params: [], use_exec: false)
      # use exec_params instead of exec when possible for security
      #
      # Unlike PQexec, PQexecParams allows at most one SQL command in the given string.
      # (There can be semicolons in it, but not more than one nonempty command.)
      # This is a limitation of the underlying protocol, but has some usefulness
      # as an extra defense against SQL-injection attacks.
      # https://www.postgresql.org/docs/current/static/libpq-exec.html
      query = squish(query) if pretty
      log colorize("[sql] #{query}#{params.any? ? " /*#{params.to_json}*/" : ""}", :cyan) if @log_sql

      @mutex.synchronize do
        if use_exec
          conn.exec("#{query} /*dexter*/").to_a
        else
          conn.exec_params("#{query} /*dexter*/", params).to_a
        end
      end
    end

    def plan(query)
      prepared = false
      transaction = false

      # try to EXPLAIN normalized queries
      # https://dev.to/yugabyte/explain-from-pgstatstatements-normalized-queries-how-to-always-get-the-generic-plan-in--5cfi
      normalized = query.include?("$1")
      generic_plan = normalized && server_version_num >= 160000
      explain_normalized = normalized && !generic_plan
      if explain_normalized
        prepared_name = "dexter_prepared"
        execute("PREPARE #{prepared_name} AS #{safe_statement(query)}", pretty: false)
        prepared = true
        params = execute("SELECT array_length(parameter_types, 1) AS params FROM pg_prepared_statements WHERE name = $1", params: [prepared_name]).first["params"].to_i
        query = "EXECUTE #{prepared_name}(#{params.times.map { "NULL" }.join(", ")})"

        execute("BEGIN")
        transaction = true

        execute("SET LOCAL plan_cache_mode = force_generic_plan")
      end

      explain_prefix = generic_plan ? "GENERIC_PLAN, " : ""

      # strip semi-colons as another measure of defense
      plan = JSON.parse(execute("EXPLAIN (#{explain_prefix}FORMAT JSON) #{safe_statement(query)}", pretty: false, use_exec: generic_plan).first["QUERY PLAN"], max_nesting: 1000).first["Plan"]

      if @log_explain
        # Pass format to prevent ANALYZE
        puts execute("EXPLAIN (#{explain_prefix}FORMAT TEXT) #{safe_statement(query)}", pretty: false, use_exec: generic_plan).map { |r| r["QUERY PLAN"] }.join("\n")
      end

      plan
    ensure
      if explain_normalized
        execute("ROLLBACK") if transaction
        execute("DEALLOCATE #{prepared_name}") if prepared
      end
    end

    # TODO for multicolumn indexes, use ordering
    def create_hypothetical_indexes_helper(columns_by_table, n, candidates)
      columns_by_table.each do |table, cols|
        # no reason to use btree index for json columns
        cols.reject { |c| ["json", "jsonb"].include?(c[:type]) }.permutation(n) do |col_set|
          index_name = create_hypothetical_index(table, col_set)
          candidates[index_name] = col_set
        end
      end
    end

    def create_hypothetical_index(table, col_set)
      execute("SELECT * FROM hypopg_create_index('CREATE INDEX ON #{quote_ident(table)} (#{col_set.map { |c| quote_ident(c[:column])  }.join(", ")})')").first["indexname"]
    end

    def database_tables
      result = execute <<~SQL
        SELECT
          table_schema || '.' || table_name AS table_name
        FROM
          information_schema.tables
        WHERE
          table_catalog = current_database()
          AND table_type IN ('BASE TABLE', 'VIEW')
      SQL
      result.map { |r| r["table_name"] }
    end

    def materialized_views
      result = execute <<~SQL
        SELECT
          schemaname || '.' || matviewname AS table_name
        FROM
          pg_matviews
      SQL
      result.map { |r| r["table_name"] }
    end

    def server_version_num
      execute("SHOW server_version_num").first["server_version_num"].to_i
    end

    def database_view_tables
      result = execute <<~SQL
        SELECT
          schemaname || '.' || viewname AS table_name,
          definition
        FROM
          pg_views
        WHERE
          schemaname NOT IN ('information_schema', 'pg_catalog')
      SQL

      view_tables = {}
      result.each do |row|
        begin
          view_tables[row["table_name"]] = PgQuery.parse(row["definition"]).tables
        rescue PgQuery::ParseError
          if @log_level.start_with?("debug")
            log colorize("ERROR: Cannot parse view definition: #{row["table_name"]}", :red)
          end
        end
      end

      view_tables
    end

    def stat_statements
      sql = <<~SQL
        SELECT
          DISTINCT query
        FROM
          pg_stat_statements
        INNER JOIN
          pg_database ON pg_database.oid = pg_stat_statements.dbid
        WHERE
          datname = current_database()
          AND (total_plan_time + total_exec_time) >= \$1
          AND calls >= \$2
        ORDER BY
          1
      SQL
      execute(sql, params: [@min_time * 60000, @min_calls.to_i]).map { |q| q["query"] }
    end

    def with_advisory_lock
      lock_id = 123456
      first_time = true
      while execute("SELECT pg_try_advisory_lock($1)", params: [lock_id]).first["pg_try_advisory_lock"] != "t"
        if first_time
          log "Waiting for lock..."
          first_time = false
        end
        sleep(1)
      end
      yield
    ensure
      suppress_messages do
        execute("SELECT pg_advisory_unlock($1)", params: [lock_id])
      end
    end

    def suppress_messages
      conn.set_notice_processor do |message|
        # do nothing
      end
      yield
    ensure
      # clear notice processor
      conn.set_notice_processor
    end

    def index_exists?(index)
      indexes([index[:table]]).find { |i| i["columns"] == index[:columns] }
    end

    def columns(tables)
      query = <<~SQL
        SELECT
          s.nspname || '.' || t.relname AS table_name,
          a.attname AS column_name,
          pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type
        FROM pg_attribute a
          JOIN pg_class t on a.attrelid = t.oid
          JOIN pg_namespace s on t.relnamespace = s.oid
        WHERE a.attnum > 0
          AND NOT a.attisdropped
          AND s.nspname || '.' || t.relname IN (#{tables.size.times.map { |i| "$#{i + 1}" }.join(", ")})
        ORDER BY
          1, 2
      SQL
      columns = execute(query, params: tables.to_a)
      columns.map { |v| {table: v["table_name"], column: v["column_name"], type: v["data_type"]} }
    end

    def indexes(tables)
      query = <<~SQL
        SELECT
          schemaname || '.' || t.relname AS table,
          ix.relname AS name,
          regexp_replace(pg_get_indexdef(i.indexrelid), '^[^\\(]*\\((.*)\\)$', '\\1') AS columns,
          regexp_replace(pg_get_indexdef(i.indexrelid), '.* USING ([^ ]*) \\(.*', '\\1') AS using
        FROM
          pg_index i
        INNER JOIN
          pg_class t ON t.oid = i.indrelid
        INNER JOIN
          pg_class ix ON ix.oid = i.indexrelid
        LEFT JOIN
          pg_stat_user_indexes ui ON ui.indexrelid = i.indexrelid
        WHERE
          schemaname || '.' || t.relname IN (#{tables.size.times.map { |i| "$#{i + 1}" }.join(", ")}) AND
          indisvalid = 't' AND
          indexprs IS NULL AND
          indpred IS NULL
        ORDER BY
          1, 2
      SQL
      execute(query, params: tables.to_a).map { |v| v["columns"] = v["columns"].sub(") WHERE (", " WHERE ").split(", ").map { |c| unquote(c) }; v }
    end

    def search_path
      execute("SELECT current_schemas(true)")[0]["current_schemas"][1..-2].split(",")
    end

    def unquote(part)
      if part && part.start_with?('"') && part.end_with?('"')
        part[1..-2]
      else
        part
      end
    end

    def quote_ident(value)
      value.split(".").map { |v| conn.quote_ident(v) }.join(".")
    end

    # from activesupport
    def squish(str)
      str.to_s.gsub(/\A[[:space:]]+/, "").gsub(/[[:space:]]+\z/, "").gsub(/[[:space:]]+/, " ")
    end

    def safe_statement(statement)
      statement.gsub(";", "")
    end
  end
end
