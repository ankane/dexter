require_relative "test_helper"

class StatementTest < Minitest::Test
  def test_basic_index
    assert_index "SELECT * FROM posts WHERE id = 1", "public.posts (id)"
  end

  def test_basic_no_index
    assert_no_index "SELECT * FROM posts"
  end

  def test_multicolumn
    assert_index "SELECT * FROM posts WHERE user_id = 1 AND blog_id = 2", "public.posts (user_id, blog_id)"
  end

  def test_multicolumn_3pass
    assert_index "SELECT * FROM posts WHERE user_id = 1 AND blog_id < 10", "public.posts (blog_id)"
  end

  def test_multicolumn_order
    assert_index "SELECT * FROM posts WHERE user_id = 1 ORDER BY blog_id LIMIT 1000", "public.posts (user_id, blog_id)"
  end

  def test_join
    assert_index "SELECT * FROM posts INNER JOIN blogs ON blogs.id = posts.blog_id WHERE blogs.id = 1", "public.posts (blog_id)"
  end

  def test_update
    assert_index "UPDATE posts SET user_id = 2 WHERE user_id = 1", "public.posts (user_id)"
  end

  def test_delete
    assert_index "DELETE FROM posts WHERE user_id = 1", "public.posts (user_id)"
  end

  def test_view
    assert_index "SELECT * FROM posts_view WHERE view_id = 1", "public.posts (id)"
  end

  def test_materialized_view
    assert_index "SELECT * FROM posts_materialized WHERE id = 1", "public.posts_materialized (id)"
  end

  def test_missing_table
    assert_no_index "SELECT * FROM missing", reason: "Tables not present in current database"
  end

  def test_foreign_table
    assert_no_index "SELECT * FROM comments WHERE post_id = 1", reason: "Tables not present in current database"
  end

  def test_cte
    assert_index "WITH cte AS (SELECT * FROM posts WHERE id = 1) SELECT * FROM cte", "public.posts (id)"
  end

  def test_cte_fence
    assert_index "WITH cte AS (SELECT * FROM posts) SELECT * FROM cte WHERE id = 1", "public.posts (id)"
  end

  def test_materialized_cte
    assert_no_index "WITH cte AS MATERIALIZED (SELECT * FROM posts) SELECT * FROM cte WHERE id = 1"
  end

  def test_not_materialized_cte
    assert_index "WITH cte AS NOT MATERIALIZED (SELECT * FROM posts) SELECT * FROM cte WHERE id = 1", "public.posts (id)"
  end

  def test_order
    assert_index "SELECT * FROM posts ORDER BY user_id DESC LIMIT 10", "public.posts (user_id)"
  end

  def test_order_column_number
    assert_index "SELECT user_id FROM posts ORDER BY 1 DESC LIMIT 10", "public.posts (user_id)"
  end

  def test_order_column_number_star
    # not ideal
    assert_no_index "SELECT * FROM posts ORDER BY 1 DESC LIMIT 10", reason: "No candidate columns for indexes"
  end

  def test_order_column_alias
    assert_index "SELECT user_id AS u FROM posts ORDER BY u DESC LIMIT 10", "public.posts (user_id)"
  end

  def test_order_multiple
    assert_index "SELECT * FROM posts ORDER BY user_id, blog_id LIMIT 10", "public.posts (user_id, blog_id)"
  end

  def test_order_multiple_direction
    skip
    assert_index "SELECT * FROM posts ORDER BY user_id DESC, blog_id LIMIT 10", "public.posts (user_id DESC, blog_id)"
  end

  def test_schema
    assert_index "SELECT * FROM \"Bar\".\"Foo\" WHERE \"Id\" = 10000", "Bar.Foo (Id)"
  end

  def test_normalized
    assert_index "SELECT * FROM posts WHERE id = $1", "public.posts (id)"
  end

  def test_no_tables
    assert_no_index "SELECT 1", reason: "No tables"
  end

  def test_information_schema
    assert_no_index "SELECT * FROM information_schema.tables", reason: "No candidate tables for indexes"
  end

  def test_pg_catalog
    assert_no_index "SELECT * FROM pg_catalog.pg_index", reason: "No candidate tables for indexes"
  end

  def test_pg_index
    assert_no_index "SELECT * FROM pg_index", reason: "No candidate tables for indexes"
  end

  def test_parse_error
    assert_no_index "SELECT +", reason: "Could not parse query"
  end

  def test_indexed
    assert_no_index "SELECT * FROM posts WHERE indexed = 1", reason: "Low initial cost"
  end
end
