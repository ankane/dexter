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
  point point,
  indexed int
);
INSERT INTO posts (id, blog_id, user_id, indexed) SELECT n, n % 1000, n % 10, n FROM generate_series(1, 100000) n;
CREATE INDEX ON posts (indexed);
CREATE VIEW posts_view AS SELECT id AS view_id FROM posts;
CREATE MATERIALIZED VIEW posts_materialized AS SELECT * FROM posts;
ANALYZE posts;

DROP TABLE IF EXISTS blogs;
CREATE TABLE blogs (
  id int PRIMARY KEY
);
INSERT INTO blogs (id) SELECT n FROM generate_series(1, 1000) n;
ANALYZE blogs;

DROP TABLE IF EXISTS events CASCADE;
CREATE TABLE events (
  id int,
  blog_id int
) PARTITION BY HASH (blog_id);
CREATE TABLE events_0 PARTITION OF events FOR VALUES WITH (MODULUS 3, REMAINDER 0);
CREATE TABLE events_1 PARTITION OF events FOR VALUES WITH (MODULUS 3, REMAINDER 1);
CREATE TABLE events_2 PARTITION OF events FOR VALUES WITH (MODULUS 3, REMAINDER 2);
INSERT INTO events (id, blog_id) SELECT n, n FROM generate_series(1, 100000) n;
ANALYZE events;

DROP SCHEMA IF EXISTS "Bar" CASCADE;
CREATE SCHEMA "Bar";
CREATE TABLE "Bar"."Foo"("Id" int);
INSERT INTO "Bar"."Foo" SELECT * FROM generate_series(1, 100000);
ANALYZE "Bar"."Foo";

CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE SERVER IF NOT EXISTS other FOREIGN DATA WRAPPER postgres_fdw;
DROP FOREIGN TABLE IF EXISTS comments;
CREATE FOREIGN TABLE comments (post_id int) SERVER other;
