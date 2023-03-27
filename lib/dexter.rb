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
require_relative "dexter/version"
require_relative "dexter/logging"
require_relative "dexter/client"
require_relative "dexter/collector"
require_relative "dexter/indexer"
require_relative "dexter/log_parser"
require_relative "dexter/stderr_log_parser"
require_relative "dexter/csv_log_parser"
require_relative "dexter/log_table_parser"
require_relative "dexter/json_log_parser"
require_relative "dexter/pg_stat_activity_parser"
require_relative "dexter/sql_log_parser"
require_relative "dexter/processor"
require_relative "dexter/query"

module Dexter
  class Abort < StandardError; end
end
