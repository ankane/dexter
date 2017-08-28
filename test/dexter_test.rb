require_relative "test_helper"

class DexterTest < Minitest::Test
  def test_basic_index
    assert_index "SELECT * FROM posts WHERE id = 1", "posts (id)"
  end

  def test_basic_no_index
    assert_no_index "SELECT * FROM posts"
  end

  def test_multicolumn_order
    assert_index "SELECT * FROM posts WHERE user_id = 1 ORDER BY blog_id LIMIT 1000", "posts (user_id, blog_id)"
  end

  def test_update
    assert_index "UPDATE posts SET user_id = 2 WHERE user_id = 1", "posts (user_id)"
  end

  def test_delete
    assert_index "DELETE FROM posts WHERE user_id = 1", "posts (user_id)"
  end

  def test_view
    # can't do views yet
    assert_no_index "SELECT * FROM posts_view WHERE id = 1"
  end

  def test_exclude
    assert_no_index "SELECT * FROM posts WHERE id = 1", "--exclude posts"
  end

  def test_exclude_other
    assert_index "SELECT * FROM posts WHERE id = 1", "posts (id)", "--exclude other"
  end

  def test_include
    assert_index "SELECT * FROM posts WHERE id = 1", "posts (id)", "--include posts"
  end

  def test_include_other
    assert_no_index "SELECT * FROM posts WHERE id = 1", "--include other"
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

  private

  def assert_index(statement, index, options = nil)
    assert_dexter_output statement, "Index found: #{index}", options
  end

  def assert_no_index(statement, options = nil)
    assert_dexter_output statement, "No new indexes found", options
  end

  def assert_dexter_output(statement, output, options)
    dexter = Dexter::Client.new(["dexter_test", "-s", statement, "--log-level", "debug2"] + options.to_s.split(" "))
    assert_output(/#{Regexp.escape(output)}/) { dexter.perform }
  end

  def assert_connection(flags)
    assert Dexter::Client.new(flags + ["-s", "SELECT 1"]).perform
  end
end
