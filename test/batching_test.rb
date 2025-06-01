require_relative "test_helper"

class BatchingTest < Minitest::Test
  def setup
    super
  end

  def test_batching
    skip unless ENV["TEST_BATCHING"]

    nc = 100
    create_table(nc)

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
    assert_match "Batch 24", output
    refute_match "Batch 25", output
  end

  def test_many_columns
    nc = 100
    create_table(nc)

    statement =  "SELECT * FROM t WHERE #{nc.times.map { |i| "c%02d = 1" % i }.join(" AND ")}"
    output = run_command("-s", statement, "--log-level", "debug2")
    assert_match "WARNING: Limiting index candidates", output
    assert_match "Index found", output
  end

  def test_column_resolution
    statement = "SELECT id, blog_id FROM posts"
    # TODO ideally would be 0
    assert_output "4 hypothetical indexes", "-s", statement, "--log-level", "debug2"
  end

  def test_column_resolution_view
    statement = "SELECT view_id FROM posts_view WHERE view_id = 1"
    # TODO ideally would be 1
    assert_output "25 hypothetical indexes", "-s", statement, "--log-level", "debug2"
  end

  private

  def create_table(nc)
    execute "DROP TABLE IF EXISTS t"
    execute "CREATE TABLE t (#{nc.times.map { |i| "c%02d int" % i }.join(", ")})"
    execute "INSERT INTO t SELECT #{nc.times.map { "n" }.join(", ")} FROM generate_series(1, 2000) n"
  end
end
