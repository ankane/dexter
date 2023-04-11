require_relative "test_helper"

class InputTest < Minitest::Test
  def test_input_format_stderr
    assert_index_file "queries.log"
  end

  def test_input_format_csv
    assert_index_file "queries.csv"
  end

  def test_input_format_json
    assert_index_file "queries.json"
  end

  def test_input_format_sql
    assert_index_file "queries.sql"
  end

  def test_pg_stat_activity
    execute("SELECT * FROM posts WHERE id = 1")
    assert_dexter_output "Index found: public.posts (id)", ["--pg-stat-activity"]
  end

  def test_pg_stat_monitor
    setup_pg_stat_monitor
    execute("SELECT * FROM posts WHERE id = 1")
    assert_dexter_output "Index found: public.posts (id)", ["--pg-stat-monitor"]
  end

  def test_pg_stat_monitor_normalized
    setup_pg_stat_monitor
    execute("SET pg_stat_monitor.pgsm_normalized_query = on")
    execute("SELECT * FROM posts WHERE id = 1")
    assert_dexter_output "Index found: public.posts (id)", ["--pg-stat-monitor"]
  end

  def test_pg_stat_statements
    execute("CREATE EXTENSION IF NOT EXISTS pg_stat_statements")
    execute("SELECT pg_stat_statements_reset()")
    execute("SELECT * FROM posts WHERE id = 1")
    assert_dexter_output "Index found: public.posts (id)", ["--pg-stat-statements"]
  end

  def test_log_table_stderr
    path = File.expand_path("support/queries.log", __dir__)
    execute("CREATE EXTENSION IF NOT EXISTS file_fdw")
    execute("CREATE SERVER IF NOT EXISTS pglog FOREIGN DATA WRAPPER file_fdw")
    execute("DROP FOREIGN TABLE IF EXISTS pglog_stderr")
    execute <<~SQL
      CREATE FOREIGN TABLE pglog_stderr (
        log_entry text
      ) SERVER pglog
      OPTIONS ( filename #{$conn.escape_literal(path)}, format 'text' )
    SQL
    assert_dexter_output "Index found: public.posts (id)", ["--log-table", "pglog_stderr"]
  end

  def test_log_table_csv
    path = File.expand_path("support/queries14.csv", __dir__)
    execute("CREATE EXTENSION IF NOT EXISTS file_fdw")
    execute("CREATE SERVER IF NOT EXISTS pglog FOREIGN DATA WRAPPER file_fdw")
    execute("DROP FOREIGN TABLE IF EXISTS pglog_csv")
    # https://www.postgresql.org/docs/current/file-fdw.html
    execute <<~SQL
      CREATE FOREIGN TABLE pglog_csv (
        log_time timestamp(3) with time zone,
        user_name text,
        database_name text,
        process_id integer,
        connection_from text,
        session_id text,
        session_line_num bigint,
        command_tag text,
        session_start_time timestamp with time zone,
        virtual_transaction_id text,
        transaction_id bigint,
        error_severity text,
        sql_state_code text,
        message text,
        detail text,
        hint text,
        internal_query text,
        internal_query_pos integer,
        context text,
        query text,
        query_pos integer,
        location text,
        application_name text,
        backend_type text,
        leader_pid integer,
        query_id bigint
      ) SERVER pglog
      OPTIONS ( filename #{$conn.escape_literal(path)}, format 'csv' )
    SQL
    assert_dexter_output "Index found: public.posts (id)", ["--log-table", "pglog_csv", "--input-format", "csv"]
  end

  def test_log_table_missing
    assert_dexter_error 'relation "missing" does not exist', ["--log-table", "missing"]
  end

  private

  def assert_index_file(file)
    file = File.expand_path("../support/#{file}", __FILE__)
    assert_dexter_output "Index found: public.posts (id)", [file]
  end

  def setup_pg_stat_monitor
    execute("CREATE EXTENSION IF NOT EXISTS pg_stat_monitor")
    execute("SELECT pg_stat_monitor_reset()")
  end
end
