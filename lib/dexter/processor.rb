module Dexter
  class Processor
    def initialize(logfile, client)
      @logfile = logfile

      @collector = Collector.new(min_time: client.options[:min_time])
      @log_parser = LogParser.new(logfile, @collector)
      @indexer = Indexer.new(client)

      @starting_interval = 3
      @interval = client.options[:interval]

      @mutex = Mutex.new
      @last_checked_at = {}
    end

    def perform
      log "Started"

      if @logfile == STDIN
        Thread.abort_on_exception = true
        Thread.new do
          sleep(@starting_interval)
          loop do
            process_queries
            sleep(@interval)
          end
        end
      end

      @log_parser.perform

      process_queries
    end

    private

    def process_queries
      @mutex.synchronize do
        process_queries_without_lock
      end
    end

    def process_queries_without_lock
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
