module Dexter
  class Client
    extend Logging
    include Logging

    attr_reader :arguments, :options

    def self.start
      Client.new(ARGV).perform
    rescue Error => e
      abort colorize(e.message.strip, :red)
    end

    def initialize(args)
      @arguments, @options = parse_args(args)
    end

    def perform
      STDOUT.sync = true
      STDERR.sync = true

      connection = Connection.new(**options.slice(:dbname, :host, :port, :username, :log_sql))
      connection.setup(options[:enable_hypopg])

      source =
        if options[:statement]
          # TODO raise error for --interval, --min-calls, --min-time
          StatementSource.new(options[:statement])
        elsif options[:pg_stat_statements]
          # TODO support streaming option
          PgStatStatementsSource.new(connection)
        elsif options[:pg_stat_activity]
          PgStatActivitySource.new(connection)
        elsif arguments.any?
          ARGV.replace(arguments)
          if !options[:input_format]
            ext = ARGV.map { |v| File.extname(v) }.uniq
            options[:input_format] = ext.first[1..-1] if ext.size == 1
          end
          LogSource.new(ARGF, options[:input_format])
        elsif options[:stdin]
          LogSource.new(STDIN, options[:input_format])
        else
          raise Error, "Specify a source of queries: --pg-stat-statements, --pg-stat-activity, --stdin, or a path"
        end

      collector = Collector.new(**options.slice(:min_time, :min_calls))

      indexer = Indexer.new(connection: connection, **options)

      Processor.new(source, collector, indexer, **options.slice(:interval)).perform
    end

    def parse_args(args)
      opts = Slop.parse(args) do |o|
        o.banner = <<~BANNER
          Usage:
              dexter [options]
        BANNER

        o.separator "Input options:"
        o.string "--input-format", "input format"
        o.boolean "--pg-stat-activity", "use pg_stat_activity", default: false
        o.boolean "--pg-stat-statements", "use pg_stat_statements", default: false, help: false
        o.boolean "--stdin", "use stdin", default: false
        o.string "-s", "--statement", "process a single statement"
        o.separator ""

        o.separator "Connection options:"
        o.string "-d", "--dbname", "database name"
        o.string "-h", "--host", "database host"
        o.integer "-p", "--port", "database port"
        o.string "-U", "--username", "database user"
        o.separator ""

        o.separator "Processing options:"
        o.integer "--interval", "time to wait between processing queries, in seconds", default: 60
        o.integer "--min-calls", "only process queries that have been called a certain number of times", default: 0
        o.float "--min-time", "only process queries that have consumed a certain amount of DB time, in minutes", default: 0
        o.separator ""

        o.separator "Indexing options:"
        o.boolean "--analyze", "analyze tables that haven't been analyzed in the past hour", default: false
        o.boolean "--create", "create indexes", default: false
        o.boolean "--enable-hypopg", "enable the HypoPG extension", default: false
        o.array "--exclude", "prevent specific tables from being indexed"
        o.string "--include", "only include specific tables"
        o.integer "--min-cost-savings-pct", default: 50, help: false
        o.string "--tablespace", "tablespace to create indexes"
        o.separator ""

        o.separator "Logging options:"
        o.boolean "--log-explain", "log explain", default: false, help: false
        o.string "--log-level", "log level", default: "info"
        o.boolean "--log-sql", "log sql", default: false
        o.separator ""

        o.separator "Other options:"
        o.on "-v", "--version", "print the version" do
          log Dexter::VERSION
          exit
        end
        o.on "--help", "prints help" do
          log o
          exit
        end
      end

      arguments = opts.arguments
      options = opts.to_hash

      options[:dbname] = arguments.shift unless options[:dbname]

      # TODO don't use global var
      $log_level = options[:log_level].to_s.downcase
      unless ["error", "info", "debug", "debug2", "debug3"].include?($log_level)
        raise Error, "Unknown log level"
      end

      [arguments, options]
    rescue Slop::Error => e
      raise Error, e.message
    end
  end
end
