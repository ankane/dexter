module Dexter
  class PgStatActivityParser < LogParser
    def perform
      previous_queries = {}

      10.times do
        active_queries = {}
        processed_queries = {}

        @logfile.stat_activity.each do |row|
          if row["state"] == "active"
            active_queries[row["id"]] = row
          else
            process_entry(row["query"], row["duration_ms"].to_f)
            processed_queries[row["id"]] = true
          end
        end

        # store queries after they complete
        previous_queries.each do |id, row|
          if !active_queries[id] && !processed_queries[id]
            process_entry(row["query"], row["duration_ms"].to_f)
          end
        end

        previous_queries = active_queries

        sleep(0.1)
      end
    end
  end
end
