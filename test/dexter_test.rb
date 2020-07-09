require_relative "test_helper"

class DexterTest < Minitest::Test
  def test_basic_index
    assert_index "SELECT * FROM posts WHERE id = 1", "public.posts (id)"
  end

  def test_basic_no_index
    assert_no_index "SELECT * FROM posts"
  end

  def test_multicolumn_order
    assert_index "SELECT * FROM posts WHERE user_id = 1 ORDER BY blog_id LIMIT 1000", "public.posts (user_id, blog_id)"
  end

  def test_update
    assert_index "UPDATE posts SET user_id = 2 WHERE user_id = 1", "public.posts (user_id)"
  end

  def test_delete
    assert_index "DELETE FROM posts WHERE user_id = 1", "public.posts (user_id)"
  end

  def test_view
    assert_index "SELECT * FROM posts_view WHERE view_id = 1", "public.posts (id)"
  end

  def test_materialized_view
    assert_index "SELECT * FROM posts_materialized WHERE id = 1", "public.posts_materialized (id)"
  end

  def test_order
    assert_index "SELECT * FROM posts ORDER BY user_id DESC LIMIT 10", "public.posts (user_id)"
  end

  def test_order_multiple
    assert_index "SELECT * FROM posts ORDER BY user_id, blog_id LIMIT 10", "public.posts (user_id, blog_id)"
  end

  def test_order_multiple_direction
    skip
    assert_index "SELECT * FROM posts ORDER BY user_id DESC, blog_id LIMIT 10", "public.posts (user_id DESC, blog_id)"
  end

  def test_exclude
    assert_no_index "SELECT * FROM posts WHERE id = 1", "--exclude posts"
  end

  def test_exclude_other
    assert_index "SELECT * FROM posts WHERE id = 1", "public.posts (id)", "--exclude other"
  end

  def test_include
    assert_index "SELECT * FROM posts WHERE id = 1", "public.posts (id)", "--include posts"
  end

  def test_include_other
    assert_no_index "SELECT * FROM posts WHERE id = 1", "--include other"
  end

  def test_schema
    assert_index "SELECT * FROM \"Bar\".\"Foo\" WHERE \"Id\" = 10000", "Bar.Foo (Id)"
  end

  def test_connection_flag
    assert_connection ["-d", "dexter_test"]
  end

  def test_connection_string
    assert_connection ["dbname=dexter_test"]
  end

  def test_connection_url_postgres
    assert_connection ["postgres://localhost/dexter_test"]
  end

  def test_connection_url_postgresql
    assert_connection ["postgresql://localhost/dexter_test"]
  end

  def test_input_format_stderr
    assert_index_file "queries.log", "stderr"
  end

  def test_input_format_csv
    assert_index_file "queries.csv", "csv"
  end

  def test_min_cost_savings
    assert_no_index "SELECT * FROM posts WHERE id = 1", "--min-cost-savings-pct 100"
  end

  private

  def assert_index(statement, index, options = nil)
    assert_dexter_output "Index found: #{index}", ["-s", statement] + options.to_s.split(" ")
  end

  def assert_index_file(file, input_format)
    file = File.expand_path("../support/#{file}", __FILE__)
    assert_dexter_output "Index found: public.posts (id)", [file, "--input-format", input_format]
  end

  def assert_no_index(statement, options = nil)
    assert_dexter_output "No new indexes found", ["-s", statement] + options.to_s.split(" ")
  end

  def assert_dexter_output(output, options)
    dexter = Dexter::Client.new(["dexter_test"] + options + ["--log-level", "debug2"])
    assert_output(/#{Regexp.escape(output)}/) { dexter.perform }
  end

  def assert_connection(flags)
    dexter = Dexter::Client.new(flags + ["-s", "SELECT 1"])
    assert_output(/#{Regexp.escape("No new indexes found")}/) { dexter.perform }
  end
end
