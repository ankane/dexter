module Dexter
  class ColumnResolver
    include Logging

    def initialize(connection, queries, log_level:)
      @connection = connection
      @queries = queries
      @log_level = log_level
    end

    def perform
      tables = Set.new(@queries.flat_map(&:tables))
      columns = tables.any? ? self.columns(tables) : []
      columns_by_table = columns.group_by { |c| c[:table] }.transform_values { |v| v.to_h { |c| [c[:column], c] } }
      columns_by_table.default = {}

      @queries.each do |query|
        log "Finding columns: #{query.statement}" if @log_level == "debug3"
        next unless query.parser_result

        columns = Set.new
        begin
          find_columns(query.tree).each do |col|
            last_col = col["fields"].last
            if last_col["String"]
              columns << last_col["String"]["sval"]
            end
          end
        rescue JSON::NestingError
          if @log_level.start_with?("debug")
            log colorize("ERROR: Cannot get columns", :red)
          end
        end

        possible_columns = []
        columns.each do |column|
          query.tables.each do |table|
            resolved = columns_by_table.dig(table, column)
            possible_columns << resolved if resolved
          end
        end
        # use all columns in tables from views (not ideal)
        query.tables_from_views.each do |table|
          possible_columns.concat(columns_by_table[table].values)
        end
        query.columns = possible_columns.uniq
      end
    end

    private

    def find_columns(plan)
      plan = JSON.parse(plan.to_json, max_nesting: 1000)
      Indexer.find_by_key(plan, "ColumnRef")
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
      columns = @connection.execute(query, params: tables.to_a)
      columns.map { |v| {table: v["table_name"], column: v["column_name"], type: v["data_type"]} }
    end
  end
end
