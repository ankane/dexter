require_relative "test_helper"

class IndexingTest < Minitest::Test
  def test_create
    assert_index "SELECT * FROM posts WHERE id = 1", "public.posts (id)", "--create"
  ensure
    execute("DROP INDEX posts_id_idx")
  end

  def test_tablespace
    assert_index "SELECT * FROM posts WHERE id = 1", "public.posts (id)", "--create --tablespace pg_default"
  ensure
    execute("DROP INDEX posts_id_idx")
  end

  def test_exclude
    assert_no_index "SELECT * FROM posts WHERE id = 1", "--exclude posts"
  end

  def test_exclude_other
    assert_index "SELECT * FROM posts WHERE id = 1", "public.posts (id)", "--exclude other"
  end

  def test_include
    assert_index "SELECT * FROM posts WHERE id = 1", "public.posts (id)", "--include posts"
  end

  def test_include_other
    assert_no_index "SELECT * FROM posts WHERE id = 1", "--include other"
  end

  def test_min_cost_savings
    assert_no_index "SELECT * FROM posts WHERE id = 1", "--min-cost-savings-pct 100"
  end
end
