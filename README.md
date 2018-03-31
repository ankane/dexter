# Dexter

The automatic indexer for Postgres

[Read about how it works](https://medium.com/@ankane/introducing-dexter-the-automatic-indexer-for-postgres-5f8fa8b28f27)

[![Build Status](https://travis-ci.org/ankane/dexter.svg?branch=master)](https://travis-ci.org/ankane/dexter)

## Installation

First, install [HypoPG](https://github.com/HypoPG/hypopg) on your database server. This doesn’t require a restart.

```sh
cd /tmp
curl -L https://github.com/HypoPG/hypopg/archive/1.1.1.tar.gz | tar xz
cd hypopg-1.1.1
make
make install # may need sudo
```

> Note: If you have issues, make sure `postgresql-server-dev-*` is installed.

Enable logging for slow queries in your Postgres config file.

```ini
log_min_duration_statement = 10 # ms
```

And install the command line tool with:

```sh
gem install pgdexter
```

The command line tool is also available as a [Linux package](guides/Linux.md).

## How to Use

Dexter needs a connection to your database and a log file to process.

```sh
tail -F -n +1 <log-file> | dexter <connection-options>
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
Processing 12 new query fingerprints
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

## Collecting Queries

There are many ways to collect queries. For real-time indexing, pipe your logfile:

```sh
tail -F -n +1 <log-file> | dexter <connection-options>
```

Pass a single statement with:

```sh
dexter <connection-options> -s "SELECT * FROM ..."
```

or pass files:

```sh
dexter <connection-options> <file1> <file2>
```

or collect running queries with: [master]

```sh
dexter <connection-options> --pg-stat-activity
```

or use the [pg_stat_statements](https://www.postgresql.org/docs/current/static/pgstatstatements.html) extension:

```sh
dexter <connection-options> --pg-stat-statements
```

> Note: Logs or running queries are highly preferred over pg_stat_statements, as pg_stat_statements often doesn’t store enough information to optimize queries.

### Collection Options

To prevent one-off queries from being indexed, specify a minimum number of calls before a query is considered for indexing

```sh
dexter --min-calls 100
```

You can do the same for total time a query has run

```sh
dexter --min-time 10 # minutes
```

Specify the format

```sh
dexter --input-format csv
```

When streaming logs, specify the time to wait between processing queries

```sh
dexter --interval 60 # seconds
```

## Examples

Ubuntu with PostgreSQL 9.6

```sh
tail -F -n +1 /var/log/postgresql/postgresql-9.6-main.log | sudo -u postgres dexter dbname
```

Homebrew on Mac

```sh
tail -F -n +1 /usr/local/var/postgres/server.log | dexter dbname
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

Some hosted providers like Amazon RDS and Heroku do not support the HypoPG extension, which Dexter needs to run. See [how to use Dexter](guides/Hosted-Postgres.md) in these cases.

## Future Work

[Here are some ideas](https://github.com/ankane/dexter/issues/1)

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

## Thanks

This software wouldn’t be possible without [HypoPG](https://github.com/dalibo/hypopg), which allows you to create hypothetical indexes, and [pg_query](https://github.com/lfittl/pg_query), which allows you to parse and fingerprint queries. A big thanks to Dalibo and Lukas Fittl respectively.

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/dexter/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/dexter/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

To get started, run:

```sh
git clone https://github.com/ankane/dexter.git
cd dexter
bundle
rake install
```

To run tests, use:

```sh
rake test
```
