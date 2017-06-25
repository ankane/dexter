require "dexter/version"
require "slop"
require "pg"
require "pg_query"
require "time"
require "set"
require "thread"
require "dexter/indexer"
require "dexter/log_parser"

module Dexter
  class Client
    attr_reader :arguments, :options

    def initialize(args)
      @arguments, @options = parse_args(args)
    end

    def perform
      abort "Missing database url" if arguments.empty?
      abort "Too many arguments" if arguments.size > 2

      # get queries
      queries = []
      if options[:s]
        queries << options[:s]
        Indexer.new(self).process_queries(queries)
      end
      if arguments[1]
        begin
          LogParser.new(arguments[1], self).perform
        rescue Errno::ENOENT
          abort "Log file not found"
        end
      end
      if !options[:s] && !arguments[1]
        LogParser.new(STDIN, self).perform
      end
    end

    def parse_args(args)
      opts = Slop.parse(args) do |o|
        o.boolean "--create", default: false
        o.string "-s"
        o.float "--min-time", default: 0
        o.integer "--interval", default: 60
      end
      [opts.arguments, opts.to_hash]
    rescue Slop::Error => e
      abort e.message
    end
  end
end
