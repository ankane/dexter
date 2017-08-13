module Dexter
  class Client
    attr_reader :arguments, :options

    def initialize(args)
      @arguments, @options = parse_args(args)
    end

    def perform
      STDOUT.sync = true
      STDERR.sync = true

      if options[:statement]
        query = Query.new(options[:statement])
        Indexer.new(arguments[0], options).process_queries([query])
      elsif options[:pg_stat_statements]
        Indexer.new(arguments[0], options).process_stat_statements
      elsif arguments[1]
        Processor.new(arguments[0], arguments[1], options).perform
      else
        Processor.new(arguments[0], STDIN, options).perform
      end
    end

    def parse_args(args)
      opts = Slop.parse(args) do |o|
        o.banner = %(Usage:
    dexter <database-url> [options]

Options:)
        o.boolean "--create", "create indexes", default: false
        o.boolean "--drop", "drop indexes", default: false
        o.boolean "--unused", "check unused indexes", default: false
        o.array "--exclude", "prevent specific tables from being indexed"
        o.integer "--interval", "time to wait between processing queries, in seconds", default: 60
        o.float "--min-time", "only process queries that have consumed a certain amount of DB time, in minutes", default: 0
        o.boolean "--pg-stat-statements", "use pg_stat_statements", default: false, help: false
        o.boolean "--log-explain", "log explain", default: false, help: false
        o.string "--log-level", "log level", default: "info"
        o.boolean "--log-sql", "log sql", default: false
        o.string "-s", "--statement", "process a single statement"
        o.on "-v", "--version", "print the version" do
          log Dexter::VERSION
          exit
        end
        o.on "-h", "--help", "prints help" do
          log o
          exit
        end
      end

      arguments = opts.arguments

      if arguments.empty?
        log opts
        exit
      end

      abort "Too many arguments" if arguments.size > 2

      abort "Unknown log level" unless ["info", "debug", "debug2"].include?(opts.to_hash[:log_level].to_s.downcase)

      [arguments, opts.to_hash]
    rescue Slop::Error => e
      abort e.message
    end

    def log(message)
      $stderr.puts message
    end
  end
end
