module Dexter
  class Indexer
    attr_reader :client

    def initialize(client)
      @client = client

      select_all("SET client_min_messages = warning")
      select_all("CREATE EXTENSION IF NOT EXISTS hypopg")
    end

    def process_queries(queries)
      # narrow down queries and tables
      tables, queries = narrow_queries(queries)
      return [] if tables.empty?

      # get ready for hypothetical indexes
      select_all("SELECT hypopg_reset()")

      # ensure tables have recently been analyzed
      analyze_tables(tables)

      # get initial plans
      initial_plans = {}
      queries.each do |query|
        begin
          initial_plans[query] = plan(query)
        rescue PG::Error
          # do nothing
        end
      end
      queries.select! { |q| initial_plans[q] }

      # get existing indexes
      index_set = Set.new
      indexes(tables).each do |index|
        # TODO make sure btree
        index_set << [index["table"], index["columns"]]
      end

      # create hypothetical indexes
      candidates = {}
      columns(tables).each do |col|
        unless index_set.include?([col[:table], [col[:column]]])
          candidates[col] = select_all("SELECT * FROM hypopg_create_index('CREATE INDEX ON #{col[:table]} (#{[col[:column]].join(", ")})');").first["indexname"]
        end
      end

      queries_by_index = {}

      new_indexes = []
      queries.each do |query|
        starting_cost = initial_plans[query]["Total Cost"]
        plan2 = plan(query)
        cost2 = plan2["Total Cost"]
        best_indexes = []

        candidates.each do |col, index_name|
          if plan2.inspect.include?(index_name)
            best_indexes << {
              table: col[:table],
              columns: [col[:column]]
            }
            (queries_by_index[best_indexes.last] ||= []) << {
              starting_cost: starting_cost,
              final_cost: cost2,
              query: query
            }
          end
        end

        # puts query
        # puts "Starting cost: #{starting_cost}"
        # puts "Final cost: #{cost2}"

        # must make it 20% faster
        if cost2 < starting_cost * 0.8
          new_indexes.concat(best_indexes)
          best_indexes.each do |index|
            # puts "CREATE INDEX CONCURRENTLY ON #{index[:table]} (#{index[:columns].join(", ")});"
          end
        else
          # puts "Nope!"
        end
        # puts
      end

      new_indexes = new_indexes.uniq.sort_by(&:to_a)

      # create indexes
      if new_indexes.any?
        # puts "Indexes to be created:"
        new_indexes.each do |index|
          statement = "CREATE INDEX CONCURRENTLY ON #{index[:table]} (#{index[:columns].join(", ")})"
          # puts "#{statement};"
          select_all(statement) if client.options[:create]
          index[:queries] = queries_by_index[index]
        end
      end

      new_indexes
    end

    def conn
      @conn ||= begin
        uri = URI.parse(client.arguments[0])
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
      conn.exec(query).to_a
    end

    def plan(query)
      JSON.parse(select_all("EXPLAIN (FORMAT JSON) #{query}").first["QUERY PLAN"]).first["Plan"]
    end

    def narrow_queries(queries)
      result = select_all <<-SQL
        SELECT
          table_name
        FROM
          information_schema.tables
        WHERE
          table_catalog = current_database() AND
          table_schema NOT IN ('pg_catalog', 'information_schema')
      SQL
      possible_tables = Set.new(result.map { |r| r["table_name"] })

      tables = queries.flat_map { |q| PgQuery.parse(q).tables }.uniq.select { |t| possible_tables.include?(t) }

      [tables, queries.select { |q| PgQuery.parse(q).tables.all? { |t| possible_tables.include?(t) } }]
    end

    def columns(tables)
      columns = select_all <<-SQL
        SELECT
          table_name,
          column_name
        FROM
          information_schema.columns
        WHERE
          table_schema = 'public' AND
          table_name IN (#{tables.map { |t| quote(t) }.join(", ")})
      SQL

      columns.map { |v| {table: v["table_name"], column: v["column_name"]} }
    end

    def indexes(tables)
      select_all(<<-SQL
        SELECT
          schemaname AS schema,
          t.relname AS table,
          ix.relname AS name,
          regexp_replace(pg_get_indexdef(i.indexrelid), '^[^\\(]*\\((.*)\\)$', '\\1') AS columns,
          regexp_replace(pg_get_indexdef(i.indexrelid), '.* USING ([^ ]*) \\(.*', '\\1') AS using,
          indisunique AS unique,
          indisprimary AS primary,
          indisvalid AS valid,
          indexprs::text,
          indpred::text,
          pg_get_indexdef(i.indexrelid) AS definition
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

    def analyze_tables(tables)
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
        if true # !last_analyzed[table] || last_analyzed[table] < Time.now - 3600
          log "Analyzing #{table}"
          select_all("ANALYZE #{table}")
        end
      end
    end

    def quote(value)
      if value.is_a?(String)
        "'#{quote_string(value)}'"
      else
        value
      end
    end

    # activerecord
    def quote_string(s)
      s.gsub(/\\/, '\&\&').gsub(/'/, "''")
    end

    def log(message)
      puts "#{Time.now.iso8601} #{message}"
    end
  end
end
