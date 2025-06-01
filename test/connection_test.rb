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

  def test_host
    assert_connection_error "could not translate host name", "-h", "bad"
  end

  def test_port
    assert_connection_error "5433", "-p", "5433"
  end

  def test_user
    assert_connection_error %{role "bad" does not exist}, "-U", "bad"
  end

  private

  def assert_connection(*args)
    output = run_command(*args, "-s", "SELECT 1", add_conninfo: false)
    assert_match "No new indexes found", output
  end

  def assert_connection_error(expected, *args)
    error = assert_raises(Dexter::Error) do
      assert_connection(*args)
    end
    assert_match expected, error.message
  end
end
