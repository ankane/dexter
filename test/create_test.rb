require_relative "test_helper"

class CreateTest < Minitest::Test
  def teardown
    execute "DROP INDEX IF EXISTS posts_id_idx"
    super
  end

  def test_create
    expected = %{Creating index: CREATE INDEX CONCURRENTLY ON "public"."posts" ("id")}
    assert_output expected, "-s", "SELECT * FROM posts WHERE id = 1", "--create"
  end

  def test_tablespace
    expected = %{Creating index: CREATE INDEX CONCURRENTLY ON "public"."posts" ("id") TABLESPACE "pg_default"}
    assert_output expected, "-s", "SELECT * FROM posts WHERE id = 1", "--create", "--tablespace", "pg_default"
  end

  def test_non_concurrently
    expected = %{Creating index: CREATE INDEX ON "public"."posts" ("id")}
    assert_output expected, "-s", "SELECT * FROM posts WHERE id = 1", "--create", "--non-concurrently"
  end

  def test_partitioned_table
    expected = %{cannot create index on partitioned table "events" concurrently}
    assert_error expected, "-s", "SELECT * FROM events WHERE blog_id = 1", "--create"
  end

  def test_partitioned_table_non_concurrently
    expected = %{Creating index: CREATE INDEX ON "public"."events" ("blog_id")}
    assert_output expected, "-s", "SELECT * FROM events WHERE blog_id = 1", "--create", "--non-concurrently"
  ensure
    execute "DROP INDEX IF EXISTS events_blog_id_idx"
  end

  def test_partition
    expected = %{Creating index: CREATE INDEX CONCURRENTLY ON "public"."events_0" ("blog_id")}
    assert_output expected, "-s", "SELECT * FROM events_0 WHERE blog_id = 1", "--create"
  ensure
    execute "DROP INDEX IF EXISTS events_0_blog_id_idx"
  end
end
