require_relative "test_helper"

class DexterTest < Minitest::Test
  def test_basic
    assert_index "SELECT * FROM posts WHERE id = 1", "posts (id)"
  end

  private

  def assert_index(statement, index)
    dexter = Dexter::Client.new(["dexter_test", "-s", statement])
    assert_output(/Index found: #{Regexp.escape(index)}/) { dexter.perform }
  end
end
