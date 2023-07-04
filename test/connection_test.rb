require_relative "test_helper"

class ConnectionTest < Minitest::Test
  def setup
    skip if ENV["DEXTER_URL"]
    super
  end

  def test_flag
    assert_connection ["-d", "dexter_test"]
  end

  def test_string
    assert_connection ["dbname=dexter_test"]
  end

  def test_url_postgres
    assert_connection ["postgres:///dexter_test"]
  end

  def test_url_postgresql
    assert_connection ["postgresql:///dexter_test"]
  end

  private

  def assert_connection(flags)
    dexter = Dexter::Client.new(flags + ["-s", "SELECT 1"])
    stdout, _ = capture_io { dexter.perform }
    puts stdout if ENV["VERBOSE"]
    assert_match "No new indexes found", stdout
  end
end
