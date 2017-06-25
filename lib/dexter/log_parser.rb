module Dexter
  class LogParser
    REGEX = /duration: (\d+\.\d+) ms  (statement|execute <unnamed>): (.+)/

    def initialize(logfile, client)
      @logfile = logfile
      @collector = Collector.new(min_time: client.options[:min_time])

      @indexer = Indexer.new(client)
      @process_queries_mutex = Mutex.new
      @last_checked_at = {}

      log "Started"

      if @logfile == STDIN
        Thread.abort_on_exception = true

        @timer_thread = Thread.new do
          sleep(3) # starting sleep
          loop do
            @process_queries_mutex.synchronize do
              process_queries
            end
            sleep(client.options[:interval])
          end
        end
      end
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
        end
      end
      process_entry(active_line, duration) if active_line

      @process_queries_mutex.synchronize do
        process_queries
      end
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
      @collector.add(query, duration) if query =~ /SELECT/i
    end

    def process_queries
      now = Time.now
      min_checked_at = now - 3600 # don't recheck for an hour
      queries = []
      @collector.fetch_queries.each do |fingerprint, query|
        if !@last_checked_at[fingerprint] || @last_checked_at[fingerprint] < min_checked_at
          queries << query
          @last_checked_at[fingerprint] = now
        end
      end

      log "Processing #{queries.size} new query fingerprints"
      @indexer.process_queries(queries) if queries.any?
    end

    def log(message)
      puts "#{Time.now.iso8601} #{message}"
    end
  end
end
