module Dexter
  class SqlLogParser < LogParser
    def perform(collector)
      # TODO support streaming
      @logfile.read.split(";").each do |statement|
        statement = statement.strip
        collector.add(statement, 0) unless statement.empty?
      end
    end
  end
end
