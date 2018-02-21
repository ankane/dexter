require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "dexter"

conn = PG::Connection.open(dbname: "dexter_test")
conn.exec <<-SQL
SET client_min_messages = warning;
CREATE EXTENSION IF NOT EXISTS hstore;
DROP TABLE IF EXISTS posts CASCADE;
CREATE TABLE posts (
  id int,
  blog_id int,
  user_id int,
  json json,
  jsonb jsonb,
  hstore hstore
);
INSERT INTO posts (SELECT n AS id, n % 1000 AS blog_id, n % 10 AS user_id FROM generate_series(1, 100000) n);
CREATE VIEW posts_view AS SELECT id AS view_id FROM posts;
CREATE MATERIALIZED VIEW posts_materialized AS SELECT * FROM posts;
ANALYZE posts;

DROP SCHEMA IF EXISTS "Bar" CASCADE;
CREATE SCHEMA "Bar";
CREATE TABLE "Bar"."Foo"("Id" int);
INSERT INTO "Bar"."Foo" SELECT * FROM generate_series(1, 100000);
ANALYZE "Bar"."Foo";
SQL
