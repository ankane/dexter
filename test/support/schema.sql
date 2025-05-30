CREATE EXTENSION IF NOT EXISTS hstore;
CREATE EXTENSION IF NOT EXISTS hypopg;

DROP TABLE IF EXISTS posts CASCADE;
CREATE TABLE posts (
  id int,
  blog_id int,
  user_id int,
  json json,
  jsonb jsonb,
  hstore hstore,
  indexed int
);
INSERT INTO posts (id, blog_id, user_id, indexed) SELECT n, n % 1000, n % 10, n FROM generate_series(1, 100000) n;
CREATE INDEX ON posts (indexed);
CREATE VIEW posts_view AS SELECT id AS view_id FROM posts;
CREATE MATERIALIZED VIEW posts_materialized AS SELECT * FROM posts;
ANALYZE posts;

DROP SCHEMA IF EXISTS "Bar" CASCADE;
CREATE SCHEMA "Bar";
CREATE TABLE "Bar"."Foo"("Id" int);
INSERT INTO "Bar"."Foo" SELECT * FROM generate_series(1, 100000);
ANALYZE "Bar"."Foo";

CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE SERVER IF NOT EXISTS other FOREIGN DATA WRAPPER postgres_fdw;
DROP FOREIGN TABLE IF EXISTS comments;
CREATE FOREIGN TABLE comments (post_id int) SERVER other;
