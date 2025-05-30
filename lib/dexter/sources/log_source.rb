module Dexter
  class LogSource
    def initialize(logfile, input_format)
      @log_parser =
        case input_format
        when "csv"
          CsvLogParser.new(logfile)
        when "json"
          JsonLogParser.new(logfile)
        when "sql"
          SqlLogParser.new(logfile)
        else
          StderrLogParser.new(logfile)
        end
      @stdin = logfile == STDIN
    end

    def perform(collector)
      @log_parser.perform(collector)
    end

    def stdin?
      @stdin
    end
  end
end
