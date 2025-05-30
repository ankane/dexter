# dependencies
require "pg"
require "pg_query"
require "slop"

# stdlib
require "csv"
require "json"
require "set"
require "time"

# modules
require_relative "dexter/logging"
require_relative "dexter/client"
require_relative "dexter/collector"
require_relative "dexter/indexer"
require_relative "dexter/processor"
require_relative "dexter/query"
require_relative "dexter/version"

# parsers
require_relative "dexter/log_parser"
require_relative "dexter/parsers/csv_log_parser"
require_relative "dexter/parsers/json_log_parser"
require_relative "dexter/parsers/pg_stat_activity_parser"
require_relative "dexter/parsers/pg_stat_statements_parser"
require_relative "dexter/parsers/sql_log_parser"
require_relative "dexter/parsers/statement_parser"
require_relative "dexter/parsers/stderr_log_parser"

module Dexter
  class Abort < StandardError; end
end
