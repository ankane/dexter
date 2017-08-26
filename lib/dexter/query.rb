module Dexter
  class Query
    attr_reader :statement, :fingerprint, :plans
    attr_accessor :missing_tables, :new_cost

    def initialize(statement, fingerprint = nil)
      @statement = statement
      unless fingerprint
        fingerprint = PgQuery.fingerprint(statement) rescue "unknown"
      end
      @fingerprint = fingerprint
      @plans = []
    end

    def tables
      @tables ||= parse ? parse.tables : []
    end

    def tree
      parse.tree
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

    def high_cost?
      initial_cost && initial_cost >= 100
    end

    private

    def parse
      unless defined?(@parse)
        @parse = PgQuery.parse(statement) rescue nil
      end
      @parse
    end
  end
end
