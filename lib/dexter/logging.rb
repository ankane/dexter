module Dexter
  module Logging
    def log(message = "")
      puts message unless $log_level == "error"
    end
  end
end
