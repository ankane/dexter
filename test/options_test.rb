require_relative "test_helper"

class OptionsTest < Minitest::Test
  def test_analyze
    execute("SELECT pg_stat_reset()")
    args = ["-s", "SELECT * FROM posts WHERE id = 1", "--log-sql"]
    output =  dexter_run(*args)
    refute_match %{Running analyze: ANALYZE "public"."posts"}, output

    output = dexter_run(*args, "--analyze")
    assert_match %{Running analyze: ANALYZE "public"."posts"}, output
    assert_match %{[sql] ANALYZE "public"."posts"}, output

    output = dexter_run(*args, "--analyze")
    refute_match %{Running analyze: ANALYZE "public"."posts"}, output
  end
end
