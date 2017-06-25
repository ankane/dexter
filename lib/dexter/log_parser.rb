module Dexter
  class LogParser
    REGEX = /duration: (\d+\.\d+) ms  (statement|execute <unnamed>): (.+)/

    def initialize(logfile, collector)
      @logfile = logfile
      @collector = collector
    end

    def perform
      active_line = nil
      duration = nil

      each_line do |line|
        if active_line
          if line.include?(":  ")
            process_entry(active_line, duration)
            active_line = nil
            duration = nil
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
        begin
          File.foreach(@logfile) do |line|
            yield line
          end
        rescue Errno::ENOENT
          abort "Log file not found"
        end
      end
    end

    def process_entry(query, duration)
      @collector.add(query, duration) if query =~ /SELECT/i
    end
  end
end
