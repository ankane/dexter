module Dexter
  class LogTableParser < LogParser
    FIRST_LINE_REGEX = /\A.+/

    def perform
      last_log_time = Time.at(0).iso8601(3)

      loop do
        @logfile.log_activity(last_log_time).each do |row|
          if (m = REGEX.match(row["message"]))
            # replace first line with match
            # needed for multiline queries
            active_line = row["message"].sub(FIRST_LINE_REGEX, m[3])

            add_parameters(active_line, row["detail"]) if row["detail"]
            process_entry(active_line, m[1].to_f)
          end

          last_log_time = row["log_time"]
        end

        break if once

        sleep(1)
      end
    end
  end
end
