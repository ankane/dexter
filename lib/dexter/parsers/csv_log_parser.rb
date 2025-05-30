module Dexter
  class CsvLogParser < LogParser
    FIRST_LINE_REGEX = /\A.+/

    def perform(collector)
      CSV.new(@logfile.to_io).each do |row|
        message = row[13]
        detail = row[14]

        if (m = REGEX.match(message))
          # replace first line with match
          # needed for multiline queries
          active_line = message.sub(FIRST_LINE_REGEX, m[3])

          add_parameters(active_line, detail) if detail
          collector.add(active_line, m[1].to_f)
        end
      end
    rescue CSV::MalformedCSVError => e
      raise Dexter::Abort, "ERROR: #{e.message}"
    end
  end
end
