module Dexter
  module Logging
    def log(message = "")
      puts message unless $log_level == "error"
    end

    def abort(message)
      raise Dexter::Abort, message
    end
  end
end
