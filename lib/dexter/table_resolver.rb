module Dexter
  class TableResolver
    include Logging

    attr_reader :queries

    def initialize(connection, queries, log_level:)
      @connection = connection
      @queries = queries
      @log_level = log_level
    end

    def perform
      tables = Set.new(database_tables + materialized_views)
      no_schema_tables = self.no_schema_tables(tables)
      view_tables = self.view_tables(no_schema_tables)

      queries.each do |query|
        # add schema to table if needed
        query.tables = query.tables.map { |t| no_schema_tables[t] || t }

        # substitute view tables
        new_tables = query.tables.flat_map { |t| view_tables[t] || [t] }.uniq
        query.tables_from_views = new_tables - query.tables
        query.tables = new_tables

        query.missing_tables = !query.tables.all? { |t| tables.include?(t) }
      end
    end

    private

    def no_schema_tables(tables)
      search_path_index = Hash[search_path.map.with_index.to_a]
      tables.group_by { |t| t.split(".")[-1] }.to_h do |group, t2|
        [group, t2.sort_by { |t| [search_path_index[t.split(".")[0]] || 1000000, t] }[0]]
      end
    end

    def view_tables(no_schema_tables)
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

      view_tables
    end

    def execute(...)
      @connection.execute(...)
    end

    def search_path
      execute("SELECT current_schemas(true)")[0]["current_schemas"][1..-2].split(",")
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
  end
end
