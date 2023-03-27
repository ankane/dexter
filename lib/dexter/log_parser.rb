module Dexter
  class LogParser
    include Logging

    REGEX = /duration: (\d+\.\d+) ms  (statement|execute [^:]+): (.+)/
    LINE_SEPERATOR = ":  ".freeze
    DETAIL_LINE = "DETAIL:  ".freeze

    attr_accessor :once

    def initialize(logfile, collector)
      @logfile = logfile
      @collector = collector
    end

    private

    def process_entry(query, duration)
      @collector.add(query, duration)
    end

    def add_parameters(active_line, details)
      if details.start_with?("parameters: ")
        params = Hash[details[12..-1].split(", ").map { |s| s.split(" = ", 2) }]

        # make sure parsing was successful
        unless params.values.include?(nil)
          params.each do |k, v|
            active_line.sub!(k, v)
          end
        end
      end
    end
  end
end
