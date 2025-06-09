module Dexter
  class StderrLogParser < LogParser
    LINE_SEPARATOR = ":  ".freeze
    DETAIL_LINE = "DETAIL:  ".freeze

    def perform(collector)
      active_line = nil
      duration = nil

      @logfile.each_line do |line|
        if active_line
          if line.include?(DETAIL_LINE)
            add_parameters(active_line, line.chomp.split(DETAIL_LINE)[1])
          elsif line.include?(LINE_SEPARATOR)
            collector.add(active_line, duration)
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
      collector.add(active_line, duration) if active_line
    end
  end
end
