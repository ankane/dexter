require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"

$url = "postgres:///dexter_test"
$conn = PG::Connection.new($url)
$conn.exec("SET client_min_messages = warning")
$conn.exec(File.read(File.expand_path("support/schema.sql", __dir__)))

class Minitest::Test
  def assert_index(statement, index, *args)
    assert_dexter_output "Index found: #{index}", "-s", statement, "--log-level", "debug2", *args
  end

  def assert_no_index(statement, *args, reason: nil)
    output = dexter_run("-s", statement, "--log-level", "debug2", *args)
    assert_match "No new indexes found", output
    assert_match reason, output if reason
  end

  def dexter_run(*args)
    dexter = Dexter::Client.new([$url] + args)
    ex = nil
    stdout, _ = capture_io do
      begin
        dexter.perform
      rescue => e
        ex = e
      end
    end
    puts stdout if ENV["VERBOSE"]
    raise ex if ex
    stdout
  end

  def assert_dexter_output(expected, *args)
    assert_match expected, dexter_run(*args)
  end

  def assert_dexter_error(expected, *args)
    error = assert_raises do
      dexter_run(*args)
    end
    assert_match expected, error.message
  end

  def server_version
    @server_version ||= execute("SHOW server_version_num").first["server_version_num"].to_i / 10000
  end

  def execute(statement)
    $conn.exec(statement)
  end
end
