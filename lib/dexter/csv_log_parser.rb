require "csv"

module Dexter
  class CsvLogParser < LogParser
    FIRST_LINE_REGEX = /\A.+/

    def perform
      CSV.new(@logfile.to_io).each do |row|
        if (m = REGEX.match(row[13]))
          # replace first line with match
          # needed for multiline queries
          active_line = row[13].sub(FIRST_LINE_REGEX, m[3])

          add_parameters(active_line, row[14]) if row[14]
          process_entry(active_line, m[1].to_f)
        end
      end
    rescue CSV::MalformedCSVError => e
      abort "ERROR: #{e.message}"
    end
  end
end
