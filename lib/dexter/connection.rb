module Dexter
  class Connection
    include Logging

    def initialize(dbname:, host:, port:, username:, log_sql:)
      @dbname = dbname
      @host = host
      @port = port
      @username = username
      @log_sql = log_sql
      @mutex = Mutex.new
    end

    def setup(enable_hypopg)
      if server_version_num < 130000
        raise Dexter::Abort, "This version of Dexter requires Postgres 13+"
      end

      check_extension(enable_hypopg)

      execute("SET lock_timeout = '5s'")
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

    def server_version_num
      @server_version_num ||= execute("SHOW server_version_num").first["server_version_num"].to_i
    end

    private

    def check_extension(enable_hypopg)
      extension = execute("SELECT installed_version FROM pg_available_extensions WHERE name = 'hypopg'").first

      if extension.nil?
        raise Dexter::Abort, "Install HypoPG first: https://github.com/ankane/dexter#installation"
      end

      if extension["installed_version"].nil?
        if enable_hypopg
          execute("CREATE EXTENSION hypopg")
        else
          raise Dexter::Abort, "Run `CREATE EXTENSION hypopg` or pass --enable-hypopg"
        end
      end
    end

    def conn
      @conn ||= begin
        # set connect timeout if none set
        ENV["PGCONNECT_TIMEOUT"] ||= "3"

        if @dbname.to_s.start_with?("postgres://", "postgresql://")
          config = @dbname
        else
          config = {
            host: @host,
            port: @port,
            dbname: @dbname,
            user: @username
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
