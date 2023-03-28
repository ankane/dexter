module Dexter
  class StderrLogParser < LogParser
    LINE_SEPERATOR = ":  ".freeze
    DETAIL_LINE = "DETAIL:  ".freeze

    def perform
      process_stderr(@logfile.each_line)
    end

    def process_stderr(rows)
      active_line = nil
      duration = nil

      rows.each do |line|
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
  end
end
