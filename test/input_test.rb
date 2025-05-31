require_relative "test_helper"

class InputTest < Minitest::Test
  def test_stderr
    assert_index_file "queries.log"
  end

  def test_csv
    assert_index_file "queries.csv"
  end

  def test_json
    assert_index_file "queries.json"
  end

  def test_sql
    assert_index_file "queries.sql"
  end

  def test_pg_stat_activity
    execute "SELECT * FROM posts WHERE id = 1"
    # TODO speed up test
    assert_output "Index found: public.posts (id)", "--pg-stat-activity"
  end

  def test_pg_stat_statements
    execute "CREATE EXTENSION IF NOT EXISTS pg_stat_statements"
    execute "SELECT pg_stat_statements_reset()"
    execute "SELECT * FROM posts WHERE id = 1"
    assert_output "Index found: public.posts (id)", "--pg-stat-statements"
    assert_output "Index found: public.posts (id)", "--pg-stat-statements", "--min-calls", "1"
  end

  def test_no_source
    assert_error "Specify a source of queries"
  end

  private

  def assert_index_file(file)
    file = File.expand_path("support/#{file}", __dir__)
    output = dexter_run(file)
    assert_match "Index found: public.posts (id)", output
    assert_match "Processing 1 new query fingerprints", output
  end
end
