module Dexter
  class ColumnResolver
    include Logging

    def initialize(connection, queries, log_level:)
      @connection = connection
      @queries = queries
      @log_level = log_level
    end

    def perform
      @queries.each do |query|
        log "Finding columns: #{query.statement}" if @log_level == "debug3"
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

        # TODO resolve possible tables
        # TODO calculate all possible indexes for query
        query.columns = columns.to_a
      end
    end

    private

    def find_columns(plan)
      plan = JSON.parse(plan.to_json, max_nesting: 1000)
      Indexer.find_by_key(plan, "ColumnRef")
    end
  end
end
