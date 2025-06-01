require_relative "test_helper"

class BatchingTest < Minitest::Test
  def setup
    super
    skip unless ENV["TEST_BATCHING"]
  end

  def test_batching
    nc = 100
    execute "DROP TABLE IF EXISTS t"
    execute "CREATE TABLE t (#{nc.times.map { |i| "c%02d int" % i }.join(", ")})"
    execute "INSERT INTO t SELECT #{nc.times.map { "n" }.join(", ")} FROM generate_series(1, 2000) n"

    queries = []
    nc.times do |i|
      (i + 1).upto(nc - 1) do |j|
        queries << "SELECT * FROM t WHERE c%02d = 0 AND c%02d = 1" % [i, j]
      end
    end
    queries.shuffle!

    tempfile = Tempfile.new
    queries.each do |query|
      tempfile << "#{query};\n"
    end
    tempfile.flush

    output = run_command(tempfile.path, "--input-format", "sql", "--log-level", "debug2")
    assert_equal nc, output.scan(/Index found/).size
    assert_match "Batches: 50", output
  end
end
