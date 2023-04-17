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
