module Dexter
  class Client
    attr_reader :arguments, :options

    def initialize(args)
      @arguments, @options = parse_args(args)
    end

    def perform
      # get queries
      queries = []
      if options[:s]
        queries << options[:s]
        Indexer.new(self).process_queries(queries)
      elsif arguments[1]
        begin
          LogParser.new(arguments[1], self).perform
        rescue Errno::ENOENT
          abort "Log file not found"
        end
      else
        LogParser.new(STDIN, self).perform
      end
    end

    def parse_args(args)
      opts = Slop.parse(args) do |o|
        o.banner = %{Usage:
    dexter <database-url> [options]

Options:}
        o.boolean "--create", "create indexes", default: false
        o.integer "--interval", "time to wait between processing queries, in seconds", default: 60
        o.float "--min-time", "only process queries that have consumed a certain amount of DB time, in minutes", default: 0
        o.string "--log-level", "log level", default: "info"
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

      if arguments.size == 0
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
