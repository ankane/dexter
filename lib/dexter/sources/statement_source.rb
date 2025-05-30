module Dexter
  class StatementSource
    def initialize(statement)
      @statement = statement
    end

    def perform(collector)
      collector.add(@statement, 0, 0, true)
    end
  end
end
