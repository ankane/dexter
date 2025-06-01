module Dexter
  class Collector
    def initialize(min_time:, min_calls:)
      @top_queries = {}
      @new_queries = Set.new
      @mutex = Mutex.new
      @min_time = min_time * 60000 # convert minutes to ms
      @min_calls = min_calls
    end

    def add(query, total_time, calls = 1, keep_all = false)
      fingerprint =
        begin
          PgQuery.fingerprint(query)
        rescue PgQuery::ParseError
          "unknown"
        end

      return if fingerprint == "unknown" && !keep_all

      @top_queries[fingerprint] ||= {calls: 0, total_time: 0}
      @top_queries[fingerprint][:calls] += calls
      @top_queries[fingerprint][:total_time] += total_time
      @top_queries[fingerprint][:query] = query
      @mutex.synchronize do
        @new_queries << fingerprint
      end
    end

    def fetch_queries
      new_queries = nil

      @mutex.synchronize do
        new_queries = @new_queries.dup
        @new_queries.clear
      end

      queries = []
      @top_queries.each do |fingerprint, query|
        if new_queries.include?(fingerprint) && query[:total_time] >= @min_time && query[:calls] >= @min_calls
          queries << Query.new(query[:query], fingerprint, total_time: query[:total_time], calls: query[:calls])
        end
      end

      queries
    end
  end
end
