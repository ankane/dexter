require "csv"

module Dexter
  class CsvLogParser < LogParser
    FIRST_LINE_REGEX = /\A.+/

    def perform
      CSV.new(@logfile.to_io).each do |row|
        process_csv_row(row[13], row[14])
      end
    rescue CSV::MalformedCSVError => e
      raise Dexter::Abort, "ERROR: #{e.message}"
    end

    def process_csv_row(message, detail)
      if (m = REGEX.match(message))
        # replace first line with match
        # needed for multiline queries
        active_line = message.sub(FIRST_LINE_REGEX, m[3])

        add_parameters(active_line, detail) if detail
        process_entry(active_line, m[1].to_f)
      end
    end
  end
end
