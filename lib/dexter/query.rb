module Dexter
  class Query
    attr_reader :statement, :fingerprint
    attr_accessor :initial_cost, :new_cost, :missing_tables

    def initialize(statement, fingerprint)
      @statement = statement
      @fingerprint = fingerprint
    end

    def tables
      @tables ||= PgQuery.parse(statement).tables rescue []
    end
  end
end
