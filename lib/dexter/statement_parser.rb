module Dexter
  class StatementParser < LogParser
    def perform
      process_entry(@logfile, 0, 0, true)
    end
  end
end
