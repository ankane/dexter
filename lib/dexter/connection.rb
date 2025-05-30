module Dexter
  class Connection
    include Logging

    def initialize(log_sql: nil, **options)
      @log_sql = log_sql
      @options = options
      @mutex = Mutex.new
    end

    def execute(query, pretty: true, params: [], use_exec: false)
      # use exec_params instead of exec when possible for security
      #
      # Unlike PQexec, PQexecParams allows at most one SQL command in the given string.
      # (There can be semicolons in it, but not more than one nonempty command.)
      # This is a limitation of the underlying protocol, but has some usefulness
      # as an extra defense against SQL-injection attacks.
      # https://www.postgresql.org/docs/current/static/libpq-exec.html
      query = squish(query) if pretty
      log colorize("[sql] #{query}#{params.any? ? " /*#{params.to_json}*/" : ""}", :cyan) if @log_sql

      @mutex.synchronize do
        if use_exec
          conn.exec("#{query} /*dexter*/").to_a
        else
          conn.exec_params("#{query} /*dexter*/", params).to_a
        end
      end
    end

    private

    def conn
      @conn ||= begin
        # set connect timeout if none set
        ENV["PGCONNECT_TIMEOUT"] ||= "3"

        if @options[:dbname].to_s.start_with?("postgres://", "postgresql://")
          config = @options[:dbname]
        else
          config = {
            host: @options[:host],
            port: @options[:port],
            dbname: @options[:dbname],
            user: @options[:username]
          }.reject { |_, value| value.to_s.empty? }
          config = config[:dbname] if config.keys == [:dbname] && config[:dbname].include?("=")
        end
        PG::Connection.new(config)
      end
    rescue PG::ConnectionBad => e
      raise Dexter::Abort, e.message
    end

    def squish(str)
      str.to_s.gsub(/\s+/, " ").strip
    end
  end
end
