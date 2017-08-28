module Dexter
  class Indexer
    include Logging

    def initialize(options)
      @create = options[:create]
      @log_level = options[:log_level]
      @exclude_tables = options[:exclude]
      @include_tables = Array(options[:include].split(",")) if options[:include]
      @log_sql = options[:log_sql]
      @log_explain = options[:log_explain]
      @min_time = options[:min_time] || 0
      @options = options

      create_extension unless extension_exists?
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

      # filter queries from other databases and system tables
      tables = possible_tables(queries)
      queries.each do |query|
        query.missing_tables = !query.tables.all? { |t| tables.include?(t) }
      end

      if @include_tables
        tables = Set.new(tables.to_a & @include_tables)
      end

      # exclude user specified tables
      # TODO exclude write-heavy tables
      @exclude_tables.each do |table|
        tables.delete(table)
      end

      # analyze tables if needed
      analyze_tables(tables) if tables.any?

      # create hypothetical indexes and explain queries
      candidates = tables.any? ? create_hypothetical_indexes(queries.reject(&:missing_tables), tables) : {}

      # see if new indexes were used and meet bar
      new_indexes = determine_indexes(queries, candidates, tables)

      # display and create new indexes
      show_and_create_indexes(new_indexes)
    end

    private

    def create_extension
      execute("SET client_min_messages = warning")
      begin
        execute("CREATE EXTENSION IF NOT EXISTS hypopg")
      rescue PG::UndefinedFile
        abort "Install HypoPG first: https://github.com/ankane/dexter#installation"
      rescue PG::InsufficientPrivilege
        abort "Use a superuser to run: CREATE EXTENSION hypopg"
      end
    end

    def extension_exists?
      execute("SELECT * FROM pg_available_extensions WHERE name = 'hypopg' AND installed_version IS NOT NULL").any?
    end

    def reset_hypothetical_indexes
      execute("SELECT hypopg_reset()")
    end

    def analyze_tables(tables)
      tables = tables.to_a.sort

      analyze_stats = execute <<-SQL
        SELECT
          schemaname AS schema,
          relname AS table,
          last_analyze,
          last_autoanalyze
        FROM
          pg_stat_user_tables
        WHERE
          relname IN (#{tables.map { |t| quote(t) }.join(", ")})
      SQL

      last_analyzed = {}
      analyze_stats.each do |stats|
        last_analyzed[stats["table"]] = Time.parse(stats["last_analyze"]) if stats["last_analyze"]
      end

      tables.each do |table|
        if !last_analyzed[table] || last_analyzed[table] < Time.now - 3600
          statement = "ANALYZE #{quote_ident(table)}"
          log "Running analyze: #{statement}"
          execute(statement)
        end
      end
    end

    def calculate_plan(queries)
      queries.each do |query|
        begin
          query.plans << plan(query.statement)
          if @log_explain
            log "Explaining query"
            puts
            # Pass format to prevent ANALYZE
            puts execute("EXPLAIN (FORMAT TEXT) #{safe_statement(query.statement)}").map { |r| r["QUERY PLAN"] }.join("\n")
            puts
          end
        rescue PG::Error
          # do nothing
        end
      end
    end

    def create_hypothetical_indexes(queries, tables)
      candidates = {}

      # get initial costs for queries
      calculate_plan(queries)
      explainable_queries = queries.select { |q| q.explainable? && q.high_cost? }

      # filter tables for performance
      tables = Set.new(explainable_queries.flat_map(&:tables))

      if tables.any?
        # get existing indexes
        index_set = Set.new
        indexes(tables).each do |index|
          # TODO make sure btree
          index_set << [index["table"], index["columns"]]
        end

        # since every set of multi-column indexes are expensive
        # try to parse out columns
        possible_columns = Set.new
        explainable_queries.each do |query|
          find_columns(query.tree).each do |col|
            last_col = col["fields"].last
            if last_col["String"]
              possible_columns << last_col["String"]["str"]
            end
          end
        end

        # create hypothetical indexes
        columns_by_table = columns(tables).select { |c| possible_columns.include?(c[:column]) }.group_by { |c| c[:table] }

        # create single column indexes
        create_hypothetical_indexes_helper(columns_by_table, 1, index_set, candidates)

        # get next round of costs
        calculate_plan(explainable_queries)

        # create multicolumn indexes
        create_hypothetical_indexes_helper(columns_by_table, 2, index_set, candidates)

        # get next round of costs
        calculate_plan(explainable_queries)
      end

      candidates
    end

    def find_columns(plan)
      find_by_key(plan, "ColumnRef")
    end

    def find_indexes(plan)
      find_by_key(plan, "Index Name")
    end

    def find_by_key(plan, key)
      indexes = []
      case plan
      when Hash
        plan.each do |k, v|
          if k == key
            indexes << v
          else
            indexes.concat(find_by_key(v, key))
          end
        end
      when Array
        indexes.concat(plan.flat_map { |v| find_by_key(v, key) })
      end
      indexes
    end

    def determine_indexes(queries, candidates, tables)
      new_indexes = {}
      index_name_to_columns = candidates.invert

      queries.each do |query|
        if query.explainable? && query.high_cost?
          new_cost, new_cost2 = query.costs[1..2]

          cost_savings = new_cost < query.initial_cost * 0.5

          # set high bar for multicolumn indexes
          cost_savings2 = new_cost > 100 && new_cost2 < new_cost * 0.5

          query.new_cost = cost_savings2 ? new_cost2 : new_cost

          query_indexes = []
          key = cost_savings2 ? 2 : 1
          indexes = find_indexes(query.plans[key]).uniq.sort

          indexes.each do |index_name|
            col_set = index_name_to_columns[index_name]

            if col_set
              index = {
                table: col_set[0][:table],
                columns: col_set.map { |c| c[:column] }
              }
              query_indexes << index

              if cost_savings || cost_savings2
                new_indexes[index] ||= index.dup
                (new_indexes[index][:queries] ||= []) << query
              end
            end
          end
        end

        if @log_level == "debug2"
          log "Processed #{query.fingerprint}"
          if tables.empty?
            log "No candidate tables for indexes"
          elsif query.explainable? && !query.high_cost?
            log "Low initial cost: #{query.initial_cost}"
          elsif query.explainable?
            log "Cost: #{query.initial_cost} -> #{query.new_cost}"

            if query_indexes.any?
              log "Indexes: #{query_indexes.map { |i| "#{i[:table]} (#{i[:columns].join(", ")})" }.join(", ")}"
              log "Need 50% cost savings to suggest index" unless cost_savings || cost_savings2
            else
              log "Indexes: None"
            end
          elsif query.fingerprint == "unknown"
            log "Could not parse query"
          elsif query.tables.empty?
            log "No tables"
          elsif query.missing_tables
            log "Tables not present in current database"
          else
            log "Could not run explain"
          end

          puts
          puts query.statement
          puts
        end
      end

      new_indexes.values.sort_by(&:to_a)
    end

    def show_and_create_indexes(new_indexes)
      if new_indexes.any?
        new_indexes.each do |index|
          log "Index found: #{index[:table]} (#{index[:columns].join(", ")})"

          if @log_level.start_with?("debug")
            index[:queries].sort_by(&:fingerprint).each do |query|
              log "Query #{query.fingerprint} (Cost: #{query.initial_cost} -> #{query.new_cost})"
              puts
              puts query.statement
              puts
            end
          end
        end

        if @create
          # 1. create lock
          # 2. refresh existing index list
          # 3. create indexes that still don't exist
          # 4. release lock
          with_advisory_lock do
            new_indexes.each do |index|
              unless index_exists?(index)
                statement = "CREATE INDEX CONCURRENTLY ON #{quote_ident(index[:table])} (#{index[:columns].map { |c| quote_ident(c) }.join(", ")})"
                log "Creating index: #{statement}"
                started_at = Time.now
                begin
                  execute(statement)
                  log "Index created: #{((Time.now - started_at) * 1000).to_i} ms"
                rescue PG::LockNotAvailable => e
                  log "Could not acquire lock: #{index[:table]}"
                end
              end
            end
          end
        end
      else
        log "No new indexes found"
      end

      new_indexes
    end

    def conn
      @conn ||= begin
        if @options[:dbname] =~ /\Apostgres(ql)?:\/\//
          config = @options[:dbname]
        else
          config = {
            host: @options[:host],
            port: @options[:port],
            dbname: @options[:dbname],
            user: @options[:user]
          }.reject { |_, value| value.to_s.empty? }
          config = config[:dbname] if config.keys == [:dbname] && config[:dbname].include?("=")
        end
        PG::Connection.new(config)
      end
    rescue PG::ConnectionBad => e
      abort e.message
    end

    def execute(query)
      # use exec_params instead of exec for security
      #
      # Unlike PQexec, PQexecParams allows at most one SQL command in the given string.
      # (There can be semicolons in it, but not more than one nonempty command.)
      # This is a limitation of the underlying protocol, but has some usefulness
      # as an extra defense against SQL-injection attacks.
      # https://www.postgresql.org/docs/current/static/libpq-exec.html
      query = squish(query)
      log "SQL: #{query}" if @log_sql
      conn.exec_params(query, []).to_a
    end

    def plan(query)
      # strip semi-colons as another measure of defense
      JSON.parse(execute("EXPLAIN (FORMAT JSON) #{safe_statement(query)}").first["QUERY PLAN"]).first["Plan"]
    end

    # TODO for multicolumn indexes, use ordering
    def create_hypothetical_indexes_helper(columns_by_table, n, index_set, candidates)
      columns_by_table.each do |table, cols|
        # no reason to use btree index for json columns
        cols.reject { |c| ["json", "jsonb"].include?(c[:type]) }.permutation(n) do |col_set|
          if !index_set.include?([table, col_set.map { |col| col[:column] }])
            candidates[col_set] = execute("SELECT * FROM hypopg_create_index('CREATE INDEX ON #{quote_ident(table)} (#{col_set.map { |c| quote_ident(c[:column])  }.join(", ")})')").first["indexname"]
          end
        end
      end
    end

    def database_tables
      result = execute <<-SQL
        SELECT
          table_name
        FROM
          information_schema.tables
        WHERE
          table_catalog = current_database() AND
          table_schema NOT IN ('pg_catalog', 'information_schema')
          AND table_type = 'BASE TABLE'
      SQL
      result.map { |r| r["table_name"] }
    end

    def stat_statements
      result = execute <<-SQL
        SELECT
          DISTINCT query
        FROM
          pg_stat_statements
        INNER JOIN
          pg_database ON pg_database.oid = pg_stat_statements.dbid
        WHERE
          datname = current_database()
          AND total_time >= #{@min_time * 60000}
        ORDER BY
          1
      SQL
      result.map { |q| q["query"] }
    end

    def possible_tables(queries)
      Set.new(queries.flat_map(&:tables).uniq & database_tables)
    end

    def with_advisory_lock
      lock_id = 123456
      first_time = true
      while execute("SELECT pg_try_advisory_lock(#{lock_id})").first["pg_try_advisory_lock"] != "t"
        if first_time
          log "Waiting for lock..."
          first_time = false
        end
        sleep(1)
      end
      yield
    ensure
      with_min_messages("error") do
        execute("SELECT pg_advisory_unlock(#{lock_id})")
      end
    end

    def with_min_messages(value)
      execute("SET client_min_messages = #{quote(value)}")
      yield
    ensure
      execute("SET client_min_messages = warning")
    end

    def index_exists?(index)
      indexes([index[:table]]).find { |i| i["columns"] == index[:columns] }
    end

    def columns(tables)
      columns = execute <<-SQL
        SELECT
          table_name,
          column_name,
          data_type
        FROM
          information_schema.columns
        WHERE
          table_schema = 'public' AND
          table_name IN (#{tables.map { |t| quote(t) }.join(", ")})
        ORDER BY
          1, 2
      SQL

      columns.map { |v| {table: v["table_name"], column: v["column_name"], type: v["data_type"]} }
    end

    def indexes(tables)
      execute(<<-SQL
        SELECT
          schemaname AS schema,
          t.relname AS table,
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
          t.relname IN (#{tables.map { |t| quote(t) }.join(", ")}) AND
          schemaname IS NOT NULL AND
          indisvalid = 't' AND
          indexprs IS NULL AND
          indpred IS NULL
        ORDER BY
          1, 2
      SQL
      ).map { |v| v["columns"] = v["columns"].sub(") WHERE (", " WHERE ").split(", ").map { |c| unquote(c) }; v }
    end

    def unquote(part)
      if part && part.start_with?('"')
        part[1..-2]
      else
        part
      end
    end

    def quote_ident(value)
      conn.quote_ident(value)
    end

    def quote(value)
      if value.is_a?(String)
        "'#{quote_string(value)}'"
      else
        value
      end
    end

    # from activerecord
    def quote_string(s)
      s.gsub(/\\/, '\&\&').gsub(/'/, "''")
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
