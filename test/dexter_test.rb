require_relative "test_helper"

class DexterTest < Minitest::Test
  def test_basic_index
    assert_index "SELECT * FROM posts WHERE id = 1", "public.posts (id)"
  end

  def test_basic_no_index
    assert_no_index "SELECT * FROM posts"
  end

  def test_multicolumn_order
    assert_index "SELECT * FROM posts WHERE user_id = 1 ORDER BY blog_id LIMIT 1000", "public.posts (user_id, blog_id)"
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

  def test_cte
    assert_index "WITH cte AS (SELECT * FROM posts WHERE id = 1) SELECT * FROM cte", "public.posts (id)"
  end

  def test_cte_fence
    if server_version >= 12
      assert_index "WITH cte AS (SELECT * FROM posts) SELECT * FROM cte WHERE id = 1", "public.posts (id)"
    else
      assert_no_index "WITH cte AS (SELECT * FROM posts) SELECT * FROM cte WHERE id = 1"
    end
  end

  def test_materialized_cte
    skip if server_version < 12

    assert_no_index "WITH MATERIALIZED cte AS (SELECT * FROM posts) SELECT * FROM cte WHERE id = 1"
  end

  def test_order
    assert_index "SELECT * FROM posts ORDER BY user_id DESC LIMIT 10", "public.posts (user_id)"
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
end
