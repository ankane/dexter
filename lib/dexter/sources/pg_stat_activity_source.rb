module Dexter
  class PgStatActivitySource
    def initialize(connection, collector)
      @connection = connection
      @collector = collector
    end

    def perform
      previous_queries = {}

      10.times do
        active_queries = {}
        processed_queries = {}

        stat_activity.each do |row|
          if row["state"] == "active"
            active_queries[row["id"]] = row
          else
            @collector.add(row["query"], row["duration_ms"].to_f)
            processed_queries[row["id"]] = true
          end
        end

        # store queries after they complete
        previous_queries.each do |id, row|
          if !active_queries[id] && !processed_queries[id]
            @collector.add(row["query"], row["duration_ms"].to_f)
          end
        end

        previous_queries = active_queries

        sleep(0.1)
      end
    end

    def stat_activity
      sql = <<~SQL
        SELECT
          pid || ':' || COALESCE(query_start, xact_start) AS id,
          query,
          state,
          EXTRACT(EPOCH FROM NOW() - COALESCE(query_start, xact_start)) * 1000.0 AS duration_ms
        FROM
          pg_stat_activity
        WHERE
          datname = current_database()
          AND pid != pg_backend_pid()
        ORDER BY
          1
      SQL
      @connection.execute(sql)
    end
  end
end
