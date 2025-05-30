module Dexter
  class SqlLogParser < LogParser
    def perform(collector)
      # TODO support streaming
      @logfile.read.split(";").each do |statement|
        collector.add(statement, 0) unless statement.strip.empty?
      end
    end
  end
end
