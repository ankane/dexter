module Dexter
  class Query
    attr_reader :statement, :fingerprint, :plans
    attr_accessor :tables, :missing_tables, :new_cost, :total_time, :calls, :indexes, :suggest_index, :pass1_indexes, :pass2_indexes, :pass3_indexes, :candidate_tables, :tables_from_views, :index_mapping, :columns, :candidate_columns

    def initialize(statement, fingerprint = nil)
      @statement = statement
      @fingerprint = fingerprint
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
      plans.map { |plan| plan["Total Cost"] }
    end

    def initial_cost
      costs[0]
    end

    def high_cost?
      initial_cost && initial_cost >= 100
    end
  end
end
