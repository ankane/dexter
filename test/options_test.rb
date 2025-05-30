require_relative "test_helper"

class OptionsTest < Minitest::Test
  def test_analyze
    execute "SELECT pg_stat_reset()"
    args = ["-s", "SELECT * FROM posts WHERE id = 1", "--log-sql"]
    refute_match "ANALYZE", dexter_run(*args)

    output = dexter_run(*args, "--analyze")
    sleep(1) if server_version < 15
    assert_match %{Running analyze: ANALYZE "public"."posts"}, output
    assert_match %{[sql] ANALYZE "public"."posts"}, output

    refute_match "ANALYZE", dexter_run(*args, "--analyze")
  end
end
