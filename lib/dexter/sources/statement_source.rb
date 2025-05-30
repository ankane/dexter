module Dexter
  class StatementSource
    def initialize(statement, collector)
      @statement = statement
      @collector = collector
    end

    def perform
      @collector.add(@statement, 0, 0, true)
    end
  end
end
