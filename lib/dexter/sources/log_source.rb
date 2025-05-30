module Dexter
  class LogSource
    def initialize(logfile, input_format, collector)
      @log_parser =
        case input_format
        when "csv"
          CsvLogParser.new(logfile, collector)
        when "json"
          JsonLogParser.new(logfile, collector)
        when "sql"
          SqlLogParser.new(logfile, collector)
        else
          StderrLogParser.new(logfile, collector)
        end
    end

    def perform
      @log_parser.perform
    end
  end
end
