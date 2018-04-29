module Dexter
  class Processor
    include Logging

    def initialize(logfile, options)
      @logfile = logfile

      @collector = Collector.new(min_time: options[:min_time], min_calls: options[:min_calls])
      @indexer = Indexer.new(options)

      @log_parser =
        if @logfile == :pg_stat_activity
          PgStatActivityParser.new(@indexer, @collector)
        elsif options[:input_format] == "csv"
          CsvLogParser.new(logfile, @collector)
        else
          LogParser.new(logfile, @collector)
        end

      @starting_interval = 3
      @interval = options[:interval]

      @mutex = Mutex.new
      @last_checked_at = {}

      log "Started"
    end

    def perform
      if [STDIN, :pg_stat_activity].include?(@logfile)
        Thread.abort_on_exception = true
        Thread.new do
          sleep(@starting_interval)
          loop do
            begin
              process_queries
            rescue PG::ServerError => e
              log "ERROR: #{e.class.name}: #{e.message}"
            end
            sleep(@interval)
          end
        end
      end

      begin
        @log_parser.perform
      rescue Errno::ENOENT => e
        abort "ERROR: #{e.message}"
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
      now = Time.now
      min_checked_at = now - 3600 # don't recheck for an hour
      queries = []
      @collector.fetch_queries.each do |query|
        if !@last_checked_at[query.fingerprint] || @last_checked_at[query.fingerprint] < min_checked_at
          queries << query
          @last_checked_at[query.fingerprint] = now
        end
      end

      log "Processing #{queries.size} new query fingerprints"
      @indexer.process_queries(queries) if queries.any?
    end
  end
end
