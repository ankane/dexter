require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"

$url = ENV["DEXTER_URL"] || "postgres:///dexter_test"
$conn = PG::Connection.new($url)
$conn.exec("SET client_min_messages = warning")
$conn.exec(File.read(File.expand_path("support/schema.sql", __dir__)))

class Minitest::Test
  def assert_index(statement, index, options = nil)
    assert_dexter_output "Index found: #{index}", ["-s", statement] + options.to_s.split(" ")
  end

  def assert_no_index(statement, options = nil, reason: nil)
    output = dexter_run(["-s", statement] + options.to_s.split(" "))
    assert_match "No new indexes found", output
    assert_match reason, output if reason
  end

  def dexter_run(options)
    dexter = Dexter::Client.new([$url] + options + ["--log-level", "debug2"])
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

  def assert_dexter_output(expected, options)
    assert_match expected, dexter_run(options)
  end

  def assert_dexter_error(expected, options)
    error = assert_raises do
      dexter_run(options)
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
