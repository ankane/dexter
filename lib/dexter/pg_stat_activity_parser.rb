module Dexter
  class PgStatActivityParser < LogParser
    def perform
      queries = {}

      10.times do
        new_queries = {}
        processed_queries = {}
        @logfile.stat_activity.each do |row|
          if row["state"] == "active"
            new_queries[row["id"]] = row
          else
            process_entry(row["query"], row["duration_ms"].to_f)
            processed_queries[row["id"]] = true
          end
        end

        # store queries after they complete
        queries.each do |id, row|
          if !new_queries[id] && !processed_queries[id]
            process_entry(row["query"], row["duration_ms"].to_f)
          end
        end

        queries = new_queries

        sleep(0.1)
      end
    end
  end
end
