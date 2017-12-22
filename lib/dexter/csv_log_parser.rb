require "csv"

module Dexter
  class CsvLogParser < LogParser
    def perform
      CSV.foreach(@logfile.file) do |row|
        if (m = REGEX.match(row[13]))
          process_entry(m[3], m[1].to_f)
        end
      end
    end
  end
end
