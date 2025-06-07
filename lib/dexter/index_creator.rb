module Dexter
  class IndexCreator
    include Logging

    def initialize(connection, indexer, new_indexes, tablespace)
      @connection = connection
      @indexer = indexer
      @new_indexes = new_indexes
      @tablespace = tablespace
    end

    # 1. create lock
    # 2. refresh existing index list
    # 3. create indexes that still don't exist
    # 4. release lock
    def perform
      with_advisory_lock do
        @new_indexes.each do |index|
          unless index_exists?(index)
            statement = String.new("CREATE INDEX CONCURRENTLY ON #{@connection.quote_ident(index[:table])} (#{index[:columns].map { |c| @connection.quote_ident(c) }.join(", ")})")
            statement << " TABLESPACE #{@connection.quote_ident(@tablespace)}" if @tablespace
            log "Creating index: #{statement}"
            started_at = monotonic_time
            begin
              @connection.execute(statement)
              log "Index created: #{((monotonic_time - started_at) * 1000).to_i} ms"
            rescue PG::LockNotAvailable
              log "Could not acquire lock: #{index[:table]}"
            end
          end
        end
      end
    end

    private

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def with_advisory_lock
      lock_id = 123456
      first_time = true
      while @connection.execute("SELECT pg_try_advisory_lock($1)", params: [lock_id]).first["pg_try_advisory_lock"] != "t"
        if first_time
          log "Waiting for lock..."
          first_time = false
        end
        sleep(1)
      end
      yield
    ensure
      suppress_messages do
        @connection.execute("SELECT pg_advisory_unlock($1)", params: [lock_id])
      end
    end

    def suppress_messages
      @connection.send(:conn).set_notice_processor do |message|
        # do nothing
      end
      yield
    ensure
      # clear notice processor
      @connection.send(:conn).set_notice_processor
    end

    def index_exists?(index)
      @indexer.send(:indexes, [index[:table]]).find { |i| i["columns"] == index[:columns] }
    end
  end
end
