module Dexter
  class Query
    attr_reader :statement, :fingerprint, :plans
    attr_writer :tables
    attr_accessor :missing_tables, :new_cost, :total_time, :calls, :indexes, :suggest_index, :pass1_indexes, :pass2_indexes, :pass3_indexes, :candidate_tables, :tables_from_views

    def initialize(statement, fingerprint = nil)
      @statement = statement
      unless fingerprint
        fingerprint = PgQuery.fingerprint(statement) rescue "unknown"
      end
      @fingerprint = fingerprint
      @plans = []
      @tables_from_views = []
    end

    def tables
      @tables ||= begin
        parse ? parse.tables : []
      rescue => e
        # possible pg_query bug
        $stderr.puts "Error extracting tables. Please report to https://github.com/ankane/dexter/issues"
        $stderr.puts "#{e.class.name}: #{e.message}"
        $stderr.puts statement
        []
      end
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
