module Dexter
  class StderrLogTableParser < StderrLogParser
    def perform
      process_stderr(@logfile.stderr_activity.map { |r| r["log_entry"] })
    end
  end
end
