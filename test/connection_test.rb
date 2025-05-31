require_relative "test_helper"

class ConnectionTest < Minitest::Test
  def test_flag
    assert_connection "-d", "dexter_test"
  end

  def test_string
    assert_connection "dbname=dexter_test"
  end

  def test_url_postgres
    assert_connection "postgres:///dexter_test"
  end

  def test_url_postgresql
    assert_connection "postgresql:///dexter_test"
  end

  private

  def assert_connection(*args)
    output = run_command(*args, "-s", "SELECT 1", add_url: false)
    assert_match "No new indexes found", output
  end
end
