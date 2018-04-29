module Dexter
  class PgStatActivityParser < LogParser
    def perform
      queries = {}

      loop do
        new_queries = {}
        @logfile.stat_activity.each do |row|
          new_queries[row["id"]] = row
        end

        # store queries after they complete
        queries.each do |id, row|
          unless new_queries[id]
            process_entry(row["query"], row["duration_ms"].to_f)
          end
        end

        queries = new_queries

        sleep(5)
      end
    end
  end
end
