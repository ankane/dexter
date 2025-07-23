module Dexter
  class Query
    attr_reader :statement, :fingerprint, :total_time, :calls, :plans
    attr_accessor :tables, :missing_tables, :new_cost, :indexes, :suggest_index, :pass1_indexes, :pass2_indexes, :pass3_indexes, :candidate_tables, :tables_from_views, :index_mapping, :columns, :candidate_columns

    def initialize(statement, fingerprint = nil, total_time: nil, calls: nil)
      @statement = statement
      @fingerprint = fingerprint
      @total_time = total_time
      @calls = calls
      @plans = []
      @tables_from_views = []
      @candidate_tables = []
      @columns = []
      @candidate_columns = []
    end

    def parser_result
      unless defined?(@parser_result)
        @parser_result = PgQuery.parse(statement) rescue nil
      end
      @parser_result
    end

    def tree
      parser_result.tree
    end

    def fully_analyzed?
      plans.size >= 3
    end

    def costs
      if plans.any?(&:nil?)
        log colorize("Failed for query: #{statement}", :yellow)
      end
      plans.compact.map { |plan| plan["Total Cost"] }
    end

    def initial_cost
      costs[0]
    end
  end
end
