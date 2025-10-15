module Dexter
  class StatementSource
    def initialize(statements)
      @statements = statements
    end

    def perform(collector)
      @statements.each do |statement|
        collector.add(statement, 0, 0, true)
      end
    end
  end
end
