# Dexter

The automatic indexer for Postgres

[Read about how it works](https://ankane.org/introducing-dexter) or [watch the talk](https://www.youtube.com/watch?v=Mni_1yTaNbE)

[![Build Status](https://github.com/ankane/dexter/workflows/build/badge.svg?branch=master)](https://github.com/ankane/dexter/actions)

## Installation

First, install [HypoPG](https://github.com/HypoPG/hypopg) on your database server. This doesn’t require a restart.

```sh
cd /tmp
curl -L https://github.com/HypoPG/hypopg/archive/1.4.0.tar.gz | tar xz
cd hypopg-1.4.0
make
make install # may need sudo
```

And enable it in databases where you want to use Dexter:

```sql
CREATE EXTENSION hypopg;
```

See the [installation notes](#hypopg-installation-notes) if you run into issues.

Then install the command line tool with:

```sh
gem install pgdexter
```

The command line tool is also available with [Docker](#docker), [Homebrew](#homebrew), or as a [Linux package](guides/Linux.md).

## How to Use

Dexter needs a connection to your database and a source of queries (like [pg_stat_statements](https://www.postgresql.org/docs/current/pgstatstatements.html)) to process.

```sh
dexter -d dbname --pg-stat-statements
```

This finds slow queries and generates output like:

```
Started
Processing 189 new query fingerprints
Index found: public.genres_movies (genre_id)
Index found: public.genres_movies (movie_id)
Index found: public.movies (title)
Index found: public.ratings (movie_id)
Index found: public.ratings (rating)
Index found: public.ratings (user_id)
```

To be safe, Dexter will not create indexes unless you pass the `--create` flag. In this case, you’ll see:

```
Index found: public.ratings (user_id)
Creating index: CREATE INDEX CONCURRENTLY ON "public"."ratings" ("user_id")
Index created: 15243 ms
```

## Connection Options

Dexter supports the same connection options as psql.

```
-h host -U user -p 5432 -d dbname
```

This includes URIs:

```
postgresql://user:pass@host:5432/dbname
```

and connection strings:

```
host=localhost port=5432 dbname=mydb
```

Always make sure your [connection is secure](https://ankane.org/postgres-sslmode-explained) when connecting to a database over a network you don’t fully trust.

## Collecting Queries

Dexter can collect queries from a number of sources.

- [Query stats](#query-stats)
- [Live queries](#live-queries)
- [Log files](#log-file)
- [SQL files](#sql-files)

### Query Stats

Enable [pg_stat_statements](https://www.postgresql.org/docs/current/pgstatstatements.html) in your database.

```psql
CREATE EXTENSION pg_stat_statements;
```

And use:

```sh
dexter <connection-options> --pg-stat-statements
```

### Live Queries

Get live queries from the [pg_stat_activity](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW) view with:

```sh
dexter <connection-options> --pg-stat-activity
```

### Log Files

Enable logging for slow queries in your Postgres config file.

```ini
log_min_duration_statement = 10 # ms
```

And use:

```sh
dexter <connection-options> postgresql.log
```

Supports `stderr`, `csvlog`, and `jsonlog` formats.

For real-time indexing, pipe your logfile:

```sh
tail -F -n +1 postgresql.log | dexter <connection-options> --stdin
```

And pass `--input-format csvlog` or `--input-format jsonlog` if needed.

### SQL Files

Pass a SQL file with:

```sh
dexter <connection-options> queries.sql
```

Pass a single query with:

```sh
dexter <connection-options> -s "SELECT * FROM ..."
```

## Collection Options

To prevent one-off queries from being indexed, specify a minimum number of calls before a query is considered for indexing

```sh
dexter --min-calls 100
```

You can do the same for total time a query has run

```sh
dexter --min-time 10 # minutes
```

When streaming logs, specify the time to wait between processing queries

```sh
dexter --interval 60 # seconds
```

## Analyze

For best results, make sure your tables have been recently analyzed so statistics are up-to-date. You can ask Dexter to analyze tables it comes across that haven’t been analyzed in the past hour with:

```sh
dexter --analyze
```

## Tables

You can exclude large or write-heavy tables from indexing with:

```sh
dexter --exclude table1,table2
```

Alternatively, you can specify which tables to index with:

```sh
dexter --include table3,table4
```

## Debugging

See how Dexter is processing queries with:

```sh
dexter --log-sql --log-level debug2
```

## Hosted Postgres

The `hypopg` extension, which Dexter needs to run, is available on [these providers](https://github.com/ankane/dexter/issues/44).

For other providers, see [this guide](guides/Hosted-Postgres.md). To request a new extension:

- Google Cloud SQL - vote or comment on [this page](https://issuetracker.google.com/issues/69250435)
- DigitalOcean Managed Databases - vote or comment on [this page](https://ideas.digitalocean.com/managed-database/p/support-hypopg-for-postgres)

## HypoPG Installation Notes

### Postgres Location

If your machine has multiple Postgres installations, specify the path to [pg_config](https://www.postgresql.org/docs/current/app-pgconfig.html) with:

```sh
export PG_CONFIG=/Applications/Postgres.app/Contents/Versions/latest/bin/pg_config
```

Then re-run the installation instructions (run `make clean` before `make` if needed)

### Missing Header

If compilation fails with `fatal error: postgres.h: No such file or directory`, make sure Postgres development files are installed on the server.

For Ubuntu and Debian, use:

```sh
sudo apt-get install postgresql-server-dev-15
```

Note: Replace `15` with your Postgres server version

## Additional Installation Methods

### Docker

Get the [Docker image](https://hub.docker.com/r/ankane/dexter) with:

```sh
docker pull ankane/dexter
```

And run it with:

```sh
docker run -ti ankane/dexter <connection-options>
```

For databases on the host machine, use `host.docker.internal` as the hostname (on Linux, this requires Docker 20.04+ and `--add-host=host.docker.internal:host-gateway`).

### Homebrew

With Homebrew, you can use:

```sh
brew install dexter
```

## Future Work

[Here are some ideas](https://github.com/ankane/dexter/issues/45)

## Upgrading

Run:

```sh
gem install pgdexter
```

To use master, run:

```sh
gem install specific_install
gem specific_install https://github.com/ankane/dexter.git
```

## Upgrade Notes

### 0.5.0

The `--stdin` option is now required to read queries from stdin.

```sh
tail -F -n +1 postgresql.log | dexter <connection-options> --stdin
```

## Thanks

This software wouldn’t be possible without [HypoPG](https://github.com/HypoPG/hypopg), which allows you to create hypothetical indexes, and [pg_query](https://github.com/lfittl/pg_query), which allows you to parse and fingerprint queries. A big thanks to Dalibo and Lukas Fittl respectively. Also, thanks to YugabyteDB for [this article](https://dev.to/yugabyte/explain-from-pgstatstatements-normalized-queries-how-to-always-get-the-generic-plan-in--5cfi) on how to explain normalized queries.

## Research

This is known as the Index Selection Problem (ISP).

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/dexter/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/dexter/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

To get started with development, run:

```sh
git clone https://github.com/ankane/dexter.git
cd dexter
bundle install
bundle exec rake install
```

To run tests, use:

```sh
createdb dexter_test
bundle exec rake test
```
