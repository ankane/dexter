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
  json json,
  jsonb jsonb,
  hstore hstore
);
INSERT INTO posts (SELECT generate_series(1,10000));
SQL
