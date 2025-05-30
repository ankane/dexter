module Dexter
  class Processor
    include Logging

    def initialize(source, connection, interval: nil, min_time: nil, min_calls: nil, **options)
      @source = source
      @collector = Collector.new(min_time: min_time, min_calls: min_calls)
      @indexer = Indexer.new(connection: connection, **options)

      @starting_interval = 3
      @interval = interval

      @mutex = Mutex.new
      @last_checked_at = {}

      log "Started" if !@source.is_a?(PgStatStatementsSource) && !@source.is_a?(StatementSource)
    end

    def perform
      if @source.is_a?(LogSource) && @source.stdin?
        Thread.abort_on_exception = true
        Thread.new do
          sleep(@starting_interval)
          loop do
            begin
              process_queries
            rescue PG::ServerError => e
              log colorize("ERROR: #{e.class.name}: #{e.message}", :red)
            end
            sleep(@interval)
          end
        end
      end

      begin
        @source.perform(@collector)
      rescue Errno::ENOENT => e
        raise Dexter::Abort, "ERROR: #{e.message}"
      end

      process_queries
    end

    private

    def process_queries
      @mutex.synchronize do
        process_queries_without_lock
      end
    end

    def process_queries_without_lock
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      min_checked_at = now - 3600 # don't recheck for an hour
      queries = []
      @collector.fetch_queries.each do |query|
        if !@last_checked_at[query.fingerprint] || @last_checked_at[query.fingerprint] < min_checked_at
          queries << query
          @last_checked_at[query.fingerprint] = now
        end
      end

      log "Processing #{queries.size} new query fingerprints" unless @source.is_a?(StatementSource)
      @indexer.process_queries(queries) if queries.any?
    end
  end
end
