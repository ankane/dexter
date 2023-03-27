module Dexter
  class CsvLogTableParser < CsvLogParser
    def perform
      last_log_time = Time.at(0).iso8601(3)

      loop do
        @logfile.csvlog_activity(last_log_time).each do |row|
          process_csv_row(row["message"], row["detail"])
          last_log_time = row["log_time"]
        end

        break

        # possibly enable later
        # break if once
        # sleep(1)
      end
    end
  end
end
