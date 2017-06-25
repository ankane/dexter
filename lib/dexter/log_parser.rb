module Dexter
  class LogParser
    REGEX = /duration: (\d+\.\d+) ms  (statement|execute <unnamed>): (.+)/

    def initialize(logfile, client)
      @logfile = logfile
      @min_time = client.options[:min_time] * 60000 # convert minutes to ms
      @top_queries = {}
      @indexer = Indexer.new(client)
    end

    def perform
      active_line = nil
      duration = nil

      each_line do |line|
        if active_line
          if line.include?(":  ")
            process_entry(active_line, duration)
            active_line = nil
            duration = nil
          else
            active_line << line
          end
        end

        if !active_line && m = REGEX.match(line.chomp)
          duration = m[1].to_f
          active_line = m[3]
        else
          # skip
        end
      end
      process_entry(active_line, duration) if active_line

      @indexer.process_queries(queries)
    end

    private

    def each_line
      if @logfile == STDIN
        STDIN.each_line do |line|
          yield line
        end
      else
        File.foreach(@logfile) do |line|
          yield line
        end
      end
    end

    def process_entry(query, duration)
      return unless query =~ /SELECT/i
      fingerprint = PgQuery.fingerprint(query)
      @top_queries[fingerprint] ||= {calls: 0, total_time: 0, query: query}
      @top_queries[fingerprint][:calls] += 1
      @top_queries[fingerprint][:total_time] += duration
    end

    def queries
      @top_queries.select { |_, v| v[:total_time] > @min_time }.map { |_, v| v[:query] }
    end
  end
end
