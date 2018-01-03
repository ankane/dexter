module Dexter
  class LogParser
    include Logging

    REGEX = /duration: (\d+\.\d+) ms  (statement|execute [^:]+): (.+)/
    LINE_SEPERATOR = ":  ".freeze
    DETAIL_LINE = "DETAIL:  ".freeze

    def initialize(logfile, collector)
      @logfile = logfile
      @collector = collector
    end

    def perform
      active_line = nil
      duration = nil

      @logfile.each_line do |line|
        if active_line
          if line.include?(DETAIL_LINE)
            add_parameters(active_line, line.chomp.split(DETAIL_LINE)[1])
          elsif line.include?(LINE_SEPERATOR)
            process_entry(active_line, duration)
            active_line = nil
          else
            active_line << line
          end
        end

        if !active_line && (m = REGEX.match(line.chomp))
          duration = m[1].to_f
          active_line = m[3]
        end
      end
      process_entry(active_line, duration) if active_line
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
