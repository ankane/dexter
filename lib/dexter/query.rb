module Dexter
  class Query
    attr_reader :statement, :fingerprint, :plans
    attr_accessor :missing_tables

    def initialize(statement, fingerprint)
      @statement = statement
      @fingerprint = fingerprint
      @plans = {}
    end

    def tables
      @tables ||= PgQuery.parse(statement).tables rescue []
    end

    def explainable?
      !initial_cost.nil?
    end

    def initial_cost
      plans[:initial] && plans[:initial]["Total Cost"]
    end

    def new_cost
      plans[:single] && plans[:single]["Total Cost"]
    end

    def final_cost
      plans[:multi] && plans[:multi]["Total Cost"]
    end
  end
end
