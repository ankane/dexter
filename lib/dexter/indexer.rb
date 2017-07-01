module Dexter
  class Indexer
    include Logging

    def initialize(database_url, options)
      @database_url = database_url
      @create = options[:create]
      @log_level = options[:log_level]
      @exclude_tables = options[:exclude]
      @log_sql = options[:log_sql]
      @log_explain = options[:log_explain]

      create_extension
    end

    def process_queries(queries)
      # reset hypothetical indexes
      reset_hypothetical_indexes

      # filter queries from other databases and system tables
      tables = possible_tables(queries)
      queries.each do |query|
        query.missing_tables = !query.tables.all? { |t| tables.include?(t) }
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
      new_indexes = determine_indexes(queries, candidates)

      # display and create new indexes
      show_and_create_indexes(new_indexes)
    end

    private

    def create_extension
      select_all("SET client_min_messages = warning")
      select_all("CREATE EXTENSION IF NOT EXISTS hypopg")
    end

    def reset_hypothetical_indexes
      select_all("SELECT hypopg_reset()")
    end

    def analyze_tables(tables)
      tables = tables.to_a.sort

      analyze_stats = select_all <<-SQL
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
          select_all(statement)
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
            puts select_all("EXPLAIN (FORMAT TEXT) #{safe_statement(query.statement)}").map { |r| r["QUERY PLAN"] }.join("\n")
            puts
          end
        rescue PG::Error
          # do nothing
        end
      end
    end

    def create_hypothetical_indexes(queries, tables)
      # get initial costs for queries
      calculate_plan(queries)
      explainable_queries = queries.select(&:explainable?)

      # get existing indexes
      index_set = Set.new
      indexes(tables).each do |index|
        # TODO make sure btree
        index_set << [index["table"], index["columns"]]
      end

      # create hypothetical indexes
      candidates = {}
      columns_by_table = columns(tables).group_by { |c| c[:table] }

      # create single column indexes
      create_hypothetical_indexes_helper(columns_by_table, 1, index_set, candidates)

      # get next round of costs
      calculate_plan(explainable_queries)

      # create multicolumn indexes
      create_hypothetical_indexes_helper(columns_by_table, 2, index_set, candidates)

      # get next round of costs
      calculate_plan(explainable_queries)

      candidates
    end

    def determine_indexes(queries, candidates)
      new_indexes = {}

      queries.each do |query|
        if query.explainable?
          new_cost, new_cost2 = query.costs[1..2]

          cost_savings = new_cost < query.initial_cost * 0.5
          # set high bar for multicolumn indexes
          cost_savings2 = new_cost > 100 && new_cost2 < new_cost * 0.5

          query.new_cost = cost_savings2 ? new_cost2 : new_cost

          query_indexes = []
          candidates.each do |col_set, index_name|
            key = cost_savings2 ? 2 : 1

            if query.plans[key].inspect.include?(index_name)
              index = {
                table: col_set[0][:table],
                columns: col_set.map { |c| c[:column] }
              }
              query_indexes << index

              if cost_savings
                new_indexes[index] ||= index.dup
                (new_indexes[index][:queries] ||= []) << query
              end
            end
          end
        end

        if @log_level == "debug2"
          log "Processed #{query.fingerprint}"
          if query.explainable?
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
          # TODO use advisory locks
          # 1. create lock
          # 2. refresh existing index list
          # 3. create indexes that still don't exist
          # 4. release lock
          new_indexes.each do |index|
            statement = "CREATE INDEX CONCURRENTLY ON #{quote_ident(index[:table])} (#{index[:columns].map { |c| quote_ident(c) }.join(", ")})"
            log "Creating index: #{statement}"
            started_at = Time.now
            select_all(statement)
            log "Index created: #{((Time.now - started_at) * 1000).to_i} ms"
          end
        end
      else
        log "No new indexes found"
      end

      new_indexes
    end

    def conn
      @conn ||= begin
        uri = URI.parse(@database_url)
        config = {
          host: uri.host,
          port: uri.port,
          dbname: uri.path.sub(/\A\//, ""),
          user: uri.user,
          password: uri.password,
          connect_timeout: 3
        }.reject { |_, value| value.to_s.empty? }
        PG::Connection.new(config)
      end
    rescue PG::ConnectionBad
      abort "Bad database url"
    end

    def select_all(query)
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
      JSON.parse(select_all("EXPLAIN (FORMAT JSON) #{safe_statement(query)}").first["QUERY PLAN"]).first["Plan"]
    end

    # TODO for multicolumn indexes, use ordering
    def create_hypothetical_indexes_helper(columns_by_table, n, index_set, candidates)
      columns_by_table.each do |table, cols|
        # no reason to use btree index for json columns
        cols.reject { |c| ["json", "jsonb"].include?(c[:type]) }.permutation(n) do |col_set|
          if !index_set.include?([table, col_set.map { |col| col[:column] }])
            candidates[col_set] = select_all("SELECT * FROM hypopg_create_index('CREATE INDEX ON #{quote_ident(table)} (#{col_set.map { |c| quote_ident(c[:column])  }.join(", ")})')").first["indexname"]
          end
        end
      end
    end

    def database_tables
      result = select_all <<-SQL
        SELECT
          table_name
        FROM
          information_schema.tables
        WHERE
          table_catalog = current_database() AND
          table_schema NOT IN ('pg_catalog', 'information_schema')
      SQL
      result.map { |r| r["table_name"] }
    end

    def possible_tables(queries)
      Set.new(queries.flat_map(&:tables).uniq & database_tables)
    end

    def columns(tables)
      columns = select_all <<-SQL
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
      select_all(<<-SQL
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
