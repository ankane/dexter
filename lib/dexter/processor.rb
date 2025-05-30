module Dexter
  class Processor
    include Logging

    def initialize(source, interval: nil, min_time: nil, min_calls: nil, **options)
      @source = source

      @collector = Collector.new(min_time: min_time, min_calls: min_calls)
      @indexer = Indexer.new(**options)

      @source_processor =
        if @source == :pg_stat_activity
          PgStatActivityParser.new(@indexer, @collector)
        elsif @source == :pg_stat_statements
          PgStatStatementsParser.new(@indexer, @collector)
        elsif @source == :statement
          StatementParser.new(options[:statement], @collector)
        elsif options[:input_format] == "csv"
          CsvLogParser.new(source, @collector)
        elsif options[:input_format] == "json"
          JsonLogParser.new(source, @collector)
        elsif options[:input_format] == "sql"
          SqlLogParser.new(source, @collector)
        else
          StderrLogParser.new(source, @collector)
        end

      @starting_interval = 3
      @interval = interval

      @mutex = Mutex.new
      @last_checked_at = {}

      log "Started" if ![:pg_stat_statements, :statement].include?(@source)
    end

    def perform
      if @source == STDIN
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
        @source_processor.perform
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

      log "Processing #{queries.size} new query fingerprints" if @source != :statement
      @indexer.process_queries(queries) if queries.any?
    end
  end
end
