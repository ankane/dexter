module Dexter
  class PgStatStatementsParser < LogParser
    def perform
      @logfile.process_stat_statements
    end
  end
end
