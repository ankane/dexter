require "csv"

module Dexter
  class CsvLogParser < LogParser
    def perform
      CSV.new(@logfile).each do |row|
        if (m = REGEX.match(row[13]))
          active_line = m[3]

          # regex only matches first line, add rest
          remaining_lines = row[13].split("\n", 2)[1]
          active_line << remaining_lines if remaining_lines

          add_parameters(active_line, row[14]) if row[14]
          process_entry(active_line, m[1].to_f)
        end
      end
    rescue CSV::MalformedCSVError => e
      abort "ERROR: #{e.message}"
    end
  end
end
