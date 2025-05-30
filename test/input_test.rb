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
    execute "SELECT * FROM posts WHERE id = 1"
    assert_dexter_output "Index found: public.posts (id)", "--pg-stat-activity"
  end

  def test_pg_stat_statements
    execute "CREATE EXTENSION IF NOT EXISTS pg_stat_statements"
    execute "SELECT pg_stat_statements_reset()"
    execute "SELECT * FROM posts WHERE id = 1"
    assert_dexter_output "Index found: public.posts (id)", "--pg-stat-statements"
    assert_dexter_output "Index found: public.posts (id)", "--pg-stat-statements", "--min-calls", "1"
  end

  def test_no_source
    assert_dexter_error "Specify a source of queries"
  end

  private

  def assert_index_file(file)
    file = File.expand_path("support/#{file}", __dir__)
    assert_dexter_output "Index found: public.posts (id)", file
  end
end
