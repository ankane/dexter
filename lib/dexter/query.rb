module Dexter
  class Query
    attr_reader :statement, :fingerprint, :plans
    attr_accessor :missing_tables, :new_cost

    def initialize(statement, fingerprint)
      @statement = statement
      @fingerprint = fingerprint
      @plans = []
    end

    def tables
      @tables ||= PgQuery.parse(statement).tables rescue []
    end

    def explainable?
      plans.any?
    end

    def costs
      plans.map { |plan| plan["Total Cost"] }
    end

    def initial_cost
      costs[0]
    end
  end
end
