require_relative "test_helper"

class IndexingTest < Minitest::Test
  def test_create
    expected = %{Creating index: CREATE INDEX CONCURRENTLY ON "public"."posts" ("id")}
    assert_output expected, "-s", "SELECT * FROM posts WHERE id = 1", "--create"
  ensure
    execute "DROP INDEX IF EXISTS posts_id_idx"
  end

  def test_tablespace
    expected = %{Creating index: CREATE INDEX CONCURRENTLY ON "public"."posts" ("id") TABLESPACE "pg_default"}
    assert_output expected, "-s", "SELECT * FROM posts WHERE id = 1", "--create", "--tablespace", "pg_default"
  ensure
    execute "DROP INDEX IF EXISTS posts_id_idx"
  end

  def test_exclude
    assert_no_index "SELECT * FROM posts WHERE id = 1", "--exclude", "posts", reason: "No candidate tables for indexes"
  end

  def test_exclude_other
    assert_index "SELECT * FROM posts WHERE id = 1", "public.posts (id)", "--exclude", "other"
  end

  def test_include
    assert_index "SELECT * FROM posts WHERE id = 1", "public.posts (id)", "--include", "posts"
  end

  def test_include_other
    assert_no_index "SELECT * FROM posts WHERE id = 1", "--include", "other", reason: "No candidate tables for indexes"
  end

  def test_min_cost_savings
    assert_no_index "SELECT * FROM posts WHERE id = 1", "--min-cost-savings-pct", "100", reason: "Need 100% cost savings to suggest index"
  end

  def test_analyze
    # last analyze time not reset consistently
    skip if server_version < 15

    execute "SELECT pg_stat_reset()"
    args = ["-s", "SELECT * FROM posts WHERE id = 1", "--log-sql"]
    refute_match "ANALYZE", run_command(*args)

    output = run_command(*args, "--analyze")
    assert_match %{Running analyze: ANALYZE "public"."posts"}, output
    assert_match %{[sql] ANALYZE "public"."posts"}, output

    refute_match "ANALYZE", run_command(*args, "--analyze")
  end

  def test_log_level_invalid
    assert_error "Unknown log level", "-s", "SELECT 1", "--log-level", "bad"
  end

  def test_batching
    skip unless ENV["TEST_BATCHING"]

    execute "DROP TABLE IF EXISTS t"
    execute "CREATE TABLE t (#{100.times.map { |i| "c%02d int" % i }.join(", ")})"
    execute "INSERT INTO t SELECT #{100.times.map { |n| n }.join(", ")} FROM generate_series(1, 2000) n"

    tempfile = Tempfile.new
    100.times do |i|
      (i + 1).upto(99) do |j|
        tempfile << "SELECT * FROM t WHERE c%02d = 1 AND c%02d = 2;\n" % [i, j]
      end
    end
    tempfile.flush

    # TODO fix
    assert_error "hypopg: not more oid available", tempfile.path, "--input-format", "sql", "--log-sql"
  end
end
