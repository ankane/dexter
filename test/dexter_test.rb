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

  private

  def assert_index(statement, index)
    assert_dexter_output statement, "Index found: #{index}"
  end

  def assert_no_index(statement)
    assert_dexter_output statement, "No new indexes found"
  end

  def assert_dexter_output(statement, output)
    dexter = Dexter::Client.new(["dexter_test", "-s", statement, "--log-level", "debug2"])
    assert_output(/#{Regexp.escape(output)}/) { dexter.perform }
  end
end
