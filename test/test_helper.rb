require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "dexter"

conn = PG::Connection.open(dbname: "dexter_test")
conn.exec <<-SQL
SET client_min_messages = warning;
CREATE EXTENSION IF NOT EXISTS hstore;
DROP TABLE IF EXISTS posts;
CREATE TABLE posts (
  id int,
  blog_id int,
  user_id int,
  json json,
  jsonb jsonb,
  hstore hstore
);
INSERT INTO posts (SELECT n AS id, n % 1000 AS blog_id, n % 10 AS user_id FROM generate_series(1, 100000) n);
ANALYZE posts;
SQL
