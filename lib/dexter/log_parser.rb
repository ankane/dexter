module Dexter
  class LogParser
    REGEX = /duration: (\d+\.\d+) ms  (statement|execute <unnamed>): (.+)/
    LINE_SEPERATOR = ":  ".freeze

    def initialize(logfile, collector)
      @logfile = logfile
      @collector = collector

      abort "Log file not found" unless File.exist?(logfile)
    end

    def perform
      active_line = nil
      duration = nil

      each_line do |line|
        if active_line
          if line.include?(LINE_SEPERATOR)
            process_entry(active_line, duration)
            active_line = nil
          else
            active_line << line
          end
        end

        if !active_line && m = REGEX.match(line.chomp)
          duration = m[1].to_f
          active_line = m[3]
        end
      end
      process_entry(active_line, duration) if active_line
    end

    private

    def each_line
      if @logfile == STDIN
        STDIN.each_line do |line|
          yield line
        end
      else
        File.foreach(@logfile) do |line|
          yield line
        end
      end
    end

    def process_entry(query, duration)
      @collector.add(query, duration)
    end
  end
end
