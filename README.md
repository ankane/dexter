# Dexter

An automatic indexer for Postgres

## Installation

First, install [HypoPG](https://github.com/dalibo/hypopg) on your database server. This doesn’t require a restart.

```sh
wget https://github.com/dalibo/hypopg/archive/1.0.0.tar.gz
tar xf 1.0.0.tar.gz
cd hypopg-1.0.0
make
make install
```

> Note: If you have issues, make sure `postgresql-server-dev-*` is installed.

Enable logging for slow queries.

```ini
log_min_duration_statement = 10 # ms
```

And install with:

```sh
gem install pgdexter
```

## How to Use

Dexter needs a connection to your database and a log file to process.

```sh
dexter <database-url> <log-file>
```

This finds slow queries and generates output like:

```
SELECT * FROM ratings ORDER BY user_id LIMIT 10
Starting cost: 3797.99
Final cost: 0.5
CREATE INDEX CONCURRENTLY ON ratings (user_id);
```

To be safe, Dexter does not create indexes unless you pass the `--create` flag.

You can also pass a single statement with:

```sh
dexter <database-url> -s "SELECT * FROM ..."
```

## Options

- `--min-time` - only consider queries that have consumed a certain amount of DB time (in minutes)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/dexter/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/dexter/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features
