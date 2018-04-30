module Dexter
  class Client
    include Logging

    attr_reader :arguments, :options

    def initialize(args)
      @arguments, @options = parse_args(args)
    end

    def perform
      STDOUT.sync = true
      STDERR.sync = true

      if options[:statement]
        query = Query.new(options[:statement])
        Indexer.new(options).process_queries([query])
      elsif options[:pg_stat_statements]
        # TODO support streaming option
        Indexer.new(options).process_stat_statements
      elsif options[:pg_stat_activity]
        Processor.new(:pg_stat_activity, options).perform
      elsif arguments.any?
        ARGV.replace(arguments)
        Processor.new(ARGF, options).perform
      else
        Processor.new(STDIN, options).perform
      end
    end

    def parse_args(args)
      opts = Slop.parse(args) do |o|
        o.banner = %(Usage:
    dexter [options]

Options:)
        o.boolean "--analyze", "analyze tables that haven't been analyzed in the past hour", default: false
        o.boolean "--create", "create indexes", default: false
        o.array "--exclude", "prevent specific tables from being indexed"
        o.string "--include", "only include specific tables"
        o.string "--input-format", "input format", default: "stderr"
        o.integer "--interval", "time to wait between processing queries, in seconds", default: 60
        o.boolean "--log-explain", "log explain", default: false, help: false
        o.string "--log-level", "log level", default: "info"
        o.boolean "--log-sql", "log sql", default: false
        o.float "--min-calls", "only process queries that have been called a certain number of times", default: 0
        o.float "--min-time", "only process queries that have consumed a certain amount of DB time, in minutes", default: 0
        o.integer "--min-cost-savings-pct", default: 50, help: false
        o.boolean "--pg-stat-activity", "use pg_stat_activity", default: false, help: false
        o.boolean "--pg-stat-statements", "use pg_stat_statements", default: false, help: false
        o.string "-s", "--statement", "process a single statement"
        # separator must go here to show up correctly - slop bug?
        o.separator ""
        o.separator "Connection options:"
        o.on "-v", "--version", "print the version" do
          log Dexter::VERSION
          exit
        end
        o.on "--help", "prints help" do
          log o
          exit
        end
        o.string "-U", "--username"
        o.string "-d", "--dbname"
        o.string "-h", "--host"
        o.integer "-p", "--port"
      end

      arguments = opts.arguments
      options = opts.to_hash

      options[:dbname] = arguments.shift unless options[:dbname]

      # TODO don't use global var
      $log_level = options[:log_level].to_s.downcase
      abort "Unknown log level" unless ["error", "info", "debug", "debug2", "debug3"].include?($log_level)

      [arguments, options]
    rescue Slop::Error => e
      abort e.message
    end
  end
end
