module Dexter
  class Indexer
    include Logging

    def initialize(connection:, **options)
      @connection = connection
      @create = options[:create]
      @tablespace = options[:tablespace]
      @log_level = options[:log_level]
      @exclude_tables = options[:exclude]
      @include_tables = Array(options[:include].split(",")) if options[:include]
      @log_explain = options[:log_explain]
      @analyze = options[:analyze]
      @min_cost = options[:min_cost].to_i
      @min_cost_savings_pct = options[:min_cost_savings_pct].to_i
      @options = options
      @server_version_num = @connection.server_version_num
    end

    # TODO recheck server version?
    def process_queries(queries)
      TableResolver.new(@connection, queries, log_level: @log_level).perform
      candidate_queries = queries.reject(&:missing_tables)

      tables = determine_tables(candidate_queries)
      candidate_queries.each do |query|
        query.candidate_tables = query.tables.select { |t| tables.include?(t) }.sort
      end
      candidate_queries.select! { |q| q.candidate_tables.any? }

      if tables.any?
        # analyze tables if needed
        # TODO remove @log_level in 0.7.0
        analyze_tables(tables) if @analyze || @log_level == "debug2"

        # get initial costs for queries
        reset_hypothetical_indexes
        calculate_plan(candidate_queries)
        candidate_queries.select! { |q| q.initial_cost && q.initial_cost >= @min_cost }

        # find columns
        ColumnResolver.new(@connection, candidate_queries, log_level: @log_level).perform
        candidate_queries.each do |query|
          # no reason to use btree index for json columns
          # TODO check type supports btree
          query.candidate_columns = query.columns.reject { |c| ["json", "jsonb", "point"].include?(c[:type]) }.sort_by { |c| [c[:table], c[:column]] }
        end
        candidate_queries.select! { |q| q.candidate_columns.any? }

        # create hypothetical indexes and explain queries
        batch_hypothetical_indexes(candidate_queries)
      end

      # see if new indexes were used and meet bar
      new_indexes = determine_indexes(queries, tables)

      # display new indexes
      show_new_indexes(new_indexes)

      # display debug info
      show_debug_info(new_indexes, queries) if @log_level.start_with?("debug")

      # create new indexes
      IndexCreator.new(@connection, self, new_indexes, @tablespace).perform if @create && new_indexes.any?
    end

    private

    def reset_hypothetical_indexes
      execute("SELECT hypopg_reset()")
    end

    def determine_tables(candidate_queries)
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

      tables
    end

    def analyze_stats(tables)
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
      execute(query, params: tables)
    end

    def analyze_tables(tables)
      tables = tables.to_a.sort

      last_analyzed = {}
      analyze_stats(tables).each do |stats|
        last_analyzed[stats["table"]] = Time.parse(stats["last_analyze"]) if stats["last_analyze"]
      end

      tables.each do |table|
        la = last_analyzed[table]

        if @log_level == "debug2"
          time_str = la ? la.iso8601 : "Unknown"
          log "Last analyze: #{table} : #{time_str}"
        end

        if @analyze && (!la || la < Time.now - 3600)
          statement = "ANALYZE #{@connection.quote_ident(table)}"
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
          plan = self.plan(query.statement)
          query.plans << plan if plan && plan["Total Cost"]
        rescue PG::Error, JSON::NestingError => e
          if @log_explain
            log e.message
          end
        end
        puts if @log_explain
      end
    end

    # process in batches to prevent "hypopg: not more oid available" error
    # https://hypopg.readthedocs.io/en/rel1_stable/usage.html#configuration
    def batch_hypothetical_indexes(candidate_queries)
      batch_count = 0
      batch = []
      single_column_indexes = Set.new
      multicolumn_indexes = Set.new

      # sort to improve batching
      # TODO improve
      candidate_queries.sort_by! { |q| q.candidate_columns.map { |c| [c[:table], c[:column]] } }

      candidate_queries.each do |query|
        batch << query

        single_column_indexes.merge(query.candidate_columns)

        # TODO for multicolumn indexes, use ordering
        columns_by_table = query.candidate_columns.group_by { |c| c[:table] }
        columns_by_table.each do |_, columns|
          multicolumn_indexes.merge(columns.permutation(2).to_a)
        end

        if single_column_indexes.size + multicolumn_indexes.size >= 500
          create_hypothetical_indexes(batch, single_column_indexes, multicolumn_indexes, batch_count)
          batch_count += 1
          batch.clear
          single_column_indexes.clear
          multicolumn_indexes.clear
        end
      end

      if batch.any?
        create_hypothetical_indexes(batch, single_column_indexes, multicolumn_indexes, batch_count)
      end
    end

    def create_candidate_indexes(candidate_indexes, index_mapping)
      candidate_indexes.each do |columns|
        begin
          index_name = create_hypothetical_index(columns[0][:table], columns.map { |c| c[:column] })
          index_mapping[index_name] = columns
        rescue PG::UndefinedObject
          # data type x has no default operator class for access method "btree"
        end
      end
    rescue PG::InternalError
      # hypopg: not more oid available
      log colorize("WARNING: Limiting index candidates", :yellow) if @log_level == "debug2"
    end

    def create_hypothetical_indexes(queries, single_column_indexes, multicolumn_indexes, batch_count)
      index_mapping = {}
      reset_hypothetical_indexes

      # check single column indexes
      create_candidate_indexes(single_column_indexes.map { |c| [c] }, index_mapping)
      calculate_plan(queries)

      # check multicolumn indexes
      create_candidate_indexes(multicolumn_indexes, index_mapping)
      calculate_plan(queries)

      # save index mapping for analysis
      queries.each do |query|
        query.index_mapping = index_mapping
      end

      # TODO different log level?
      log "Batch #{batch_count + 1}: #{queries.size} queries, #{index_mapping.size} hypothetical indexes" if @log_level == "debug2"
    end

    def find_indexes(plan)
      self.class.find_by_key(plan, "Index Name")
    end

    def self.find_by_key(plan, key)
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

    def hypo_indexes_from_plan(index_mapping, plan, index_set)
      query_indexes = []

      find_indexes(plan).uniq.sort.each do |index_name|
        columns = index_mapping[index_name]

        if columns
          index = {
            table: columns[0][:table],
            columns: columns.map { |c| c[:column] }
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

      savings_ratio = 1 - @min_cost_savings_pct / 100.0

      queries.each do |query|
        if query.fully_analyzed?
          new_cost, new_cost2 = query.costs[1..2]

          cost_savings = new_cost < query.initial_cost * savings_ratio

          # set high bar for multicolumn indexes
          cost_savings2 = new_cost > 100 && new_cost2 < new_cost * savings_ratio

          key = cost_savings2 ? 2 : 1
          query_indexes = hypo_indexes_from_plan(query.index_mapping, query.plans[key], index_set)

          # likely a bad suggestion, so try single column
          if cost_savings2 && query_indexes.size > 1
            query_indexes = hypo_indexes_from_plan(query.index_mapping, query.plans[1], index_set)
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
              create_hypothetical_index(query_index[:table], query_index[:columns])
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
            query.pass1_indexes = hypo_indexes_from_plan(query.index_mapping, query.plans[1], index_set)
            query.pass2_indexes = hypo_indexes_from_plan(query.index_mapping, query.plans[2], index_set)
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

    def show_new_indexes(new_indexes)
      if new_indexes.any?
        new_indexes.each do |index|
          log colorize("Index found: #{index[:table]} (#{index[:columns].join(", ")})", :green)
        end
      else
        log "No new indexes found"
      end
    end

    def show_debug_info(new_indexes, queries)
      index_queries = new_indexes.flat_map { |i| i[:queries].sort_by(&:fingerprint) }
      if @log_level == "debug2"
        fingerprints = Set.new(index_queries.map(&:fingerprint))
        index_queries.concat(queries.reject { |q| fingerprints.include?(q.fingerprint) }.sort_by(&:fingerprint))
      end
      index_queries.each do |query|
        log "-" * 80
        log "Query #{query.fingerprint}"
        log "Total time: #{(query.total_time / 60000.0).round(1)} min, avg time: #{(query.total_time / query.calls.to_f).round} ms, calls: #{query.calls}" if query.calls > 0

        if query.fingerprint == "unknown"
          log "Could not parse query"
        elsif query.tables.empty?
          log "No tables"
        elsif query.missing_tables
          log "Tables not present in current database"
        elsif query.candidate_tables.empty?
          log "No candidate tables for indexes"
        elsif !query.initial_cost
          log "Could not run explain"
        elsif query.initial_cost < @min_cost
          log "Low initial cost: #{query.initial_cost}"
        elsif query.candidate_columns.empty?
          log "No candidate columns for indexes"
        elsif query.fully_analyzed?
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

    def execute(...)
      @connection.execute(...)
    end

    def plan(query)
      prepared = false
      transaction = false

      # try to EXPLAIN normalized queries
      # https://dev.to/yugabyte/explain-from-pgstatstatements-normalized-queries-how-to-always-get-the-generic-plan-in--5cfi
      normalized = query.include?("$1")
      generic_plan = normalized && @server_version_num >= 160000
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

    def create_hypothetical_index(table, columns)
      execute("SELECT * FROM hypopg_create_index('CREATE INDEX ON #{@connection.quote_ident(table)} (#{columns.map { |c| @connection.quote_ident(c) }.join(", ")})')").first["indexname"]
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

    def unquote(part)
      if part && part.start_with?('"') && part.end_with?('"')
        part[1..-2]
      else
        part
      end
    end

    def safe_statement(statement)
      statement.gsub(";", "")
    end
  end
end
