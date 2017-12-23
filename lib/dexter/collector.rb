module Dexter
  class Collector
    def initialize(options = {})
      @top_queries = {}
      @new_queries = Set.new
      @mutex = Mutex.new
      @min_time = options[:min_time] * 60000 # convert minutes to ms
      @min_calls = options[:min_calls]
    end

    def add(query, duration)
      fingerprint =
        begin
          PgQuery.fingerprint(query)
        rescue PgQuery::ParseError
          # do nothing
        end

      return unless fingerprint

      @top_queries[fingerprint] ||= {calls: 0, total_time: 0}
      @top_queries[fingerprint][:calls] += 1
      @top_queries[fingerprint][:total_time] += duration
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
      @top_queries.each do |k, v|
        if new_queries.include?(k) && v[:total_time] >= @min_time && v[:calls] >= @min_calls
          query = Query.new(v[:query], k)
          query.total_time = v[:total_time]
          query.calls = v[:calls]
          queries << query
        end
      end

      queries.sort_by(&:fingerprint)
    end
  end
end
