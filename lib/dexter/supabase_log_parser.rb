module Dexter
  class SupabaseLogParser < LogParser
    def perform
      active_line = nil

      # cannot parse as CSV since quotes not escaped
      @logfile.each_line do |line|
        if line =~ /\A"(LOG|ERROR)",/
          process_line(active_line) if active_line
          active_line = nil
        end

        if active_line
          active_line << line
        else
          active_line = line
        end
      end
      process_line(active_line) if active_line
    end

    # 4 columns, but quotes not escaped in second column
    def process_line(line)
      if line.start_with?('"LOG","AUDIT: ')
        last_index = line[0...line.rindex(",")].rindex(",") - 2
        audit = line[14..last_index]
        statement = CSV.parse_line(audit)[7]
        process_entry(statement, 0)
      end
    end
  end
end
