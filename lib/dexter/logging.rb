module Dexter
  module Logging
    def log(message)
      puts "#{Time.now.iso8601} #{message}" unless $log_level == "error"
    end
  end
end
