require_relative "test_helper"

class InputTest < Minitest::Test
  def test_stderr
    assert_index_file "queries.log"
  end

  def test_csv
    assert_index_file "queries.csv"
  end

  def test_csv_invalid
    assert_error "Illegal quoting", support_path("queries.json"), "--input-format", "csv"
  end

  def test_json
    assert_index_file "queries.json"
  end

  def test_json_invalid
    assert_error "unexpected token", support_path("queries.log"), "--input-format", "json"
  end

  def test_sql
    assert_index_file "queries.sql"
  end

  def test_pg_stat_activity
    execute "SELECT * FROM posts WHERE id = 1"
    assert_output "Index found: public.posts (id)", "--pg-stat-activity"
  end

  def test_pg_stat_statements
    execute "CREATE EXTENSION IF NOT EXISTS pg_stat_statements"
    execute "SELECT pg_stat_statements_reset()"
    execute "SELECT * FROM posts WHERE id = 1"
    execute "REFRESH MATERIALIZED VIEW posts_materialized"
    assert_output "Index found: public.posts (id)", "--pg-stat-statements"
    assert_output "Index found: public.posts (id)", "--pg-stat-statements", "--min-calls", "1"
  end

  def test_pg_stat_statements_missing
    execute "DROP EXTENSION IF EXISTS pg_stat_statements"
    assert_error %{relation "pg_stat_statements" does not exist}, "--pg-stat-statements"
  end

  def test_no_source
    assert_error "Specify a source of queries"
  end

  def test_input_format_invalid
    assert_error "Unknown input format", support_path("queries.json"), "--input-format", "bad"
  end

  private

  def support_path(file)
    File.expand_path("support/#{file}", __dir__)
  end

  def assert_index_file(file)
    output = run_command(support_path(file))
    assert_match "Index found: public.posts (id)", output
    assert_match "Processing 1 new query fingerprints", output
  end
end
