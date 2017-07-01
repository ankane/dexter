module Dexter
  class Query
    attr_reader :statement, :fingerprint, :plans
    attr_accessor :missing_tables

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
  end
end
