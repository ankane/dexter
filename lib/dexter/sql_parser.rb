module Dexter
  class SqlParser < LogParser
    def perform
      # TODO support streaming
      @logfile.read.split(";").each do |statement|
        process_entry(statement, 1)
      end
    end
  end
end
