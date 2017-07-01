require_relative "test_helper"

class DexterTest < Minitest::Test
  def test_basic_index
    assert_index "SELECT * FROM posts WHERE id = 1", "posts (id)"
  end

  def test_basic_no_index
    assert_no_index "SELECT * FROM posts"
  end

  private

  def assert_index(statement, index)
    dexter = Dexter::Client.new(["dexter_test", "-s", statement])
    assert_output(/Index found: #{Regexp.escape(index)}/) { dexter.perform }
  end

  def assert_no_index(statement)
    # TODO DRY
    dexter = Dexter::Client.new(["dexter_test", "-s", statement])
    assert_output(/No indexes found/) { dexter.perform }
  end
end
