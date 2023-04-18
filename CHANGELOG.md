## 0.5.0 (2023-04-18)

- Added support for normalized queries
- Added `--stdin` option (now required to read from stdin)
- Added `--enable-hypopg` option (now required to enable HypoPG)
- Improved output when HypoPG not installed
- Changed `--pg-stat-activity` to sample 10 times and exit
- Detect input format based on file extension
- Dropped support for experimental `--log-table` option
- Dropped support for Linux packages for Ubuntu 18.04 and Debian 10
- Dropped support for Ruby < 2.7
- Dropped support for Postgres < 11

## 0.4.3 (2023-03-26)

- Added experimental `--log-table` option
- Improved help
- Require pg_query < 4

## 0.4.2 (2023-01-29)

- Fixed `--pg-stat-statements` option for Postgres 13+

## 0.4.1 (2022-10-15)

- Added support for `json` format

## 0.4.0 (2022-07-27)

- Added support for pg_query 2
- Switched to monotonic time
- Dropped support for Ruby < 2.5

## 0.3.10 (2021-03-25)

- Require pg_query < 2

## 0.3.9 (2020-11-23)

- Added `--tablespace` option

## 0.3.8 (2020-08-17)

- Colorize output
- Fixed error when unable to parse view definitions

## 0.3.7 (2020-07-10)

- Fixed help output

## 0.3.6 (2020-03-30)

- Fixed warning with Ruby 2.7

## 0.3.5 (2018-04-30)

- Added `sql` input format
- Fixed error for queries with double dash comments
- Fixed connection threading issue with `--pg-stat-activity` option

## 0.3.4 (2018-04-09)

- Fixed `--username` option
- Fixed `JSON::NestingError`
- Added `--pg-stat-activity` option

## 0.3.3 (2018-02-22)

- Added support for views and materialized views
- Better handle case when multiple indexes are found for a query
- Added `--min-cost-savings-pct` option

## 0.3.2 (2018-01-04)

- Fixed parsing issue with named prepared statements
- Fixed parsing issue with multiline queries in csv format
- Better explanations for indexing decisions

## 0.3.1 (2017-12-28)

- Added support for queries with bind variables
- Fixed error with streaming logs as csv format
- Handle malformed CSV gracefully

## 0.3.0 (2017-12-22)

- Added support for schemas
- Added support for csv format
- Added `--analyze` option and do not analyze by default
- Added `--min-calls` option
- Fixed debug output when indexes not found

## 0.2.1 (2017-09-02)

- Fixed bad suggestions
- Improved debugging output

## 0.2.0 (2017-08-27)

- Added same connection options as `psql`
- Added support for multiple files
- Added `error` log level
- Better error messages when cannot connect

Breaking

- `-h` option changed to `--host` instead of `--help` for consistency with `psql`

## 0.1.6 (2017-08-26)

- Significant performance improvements
- Added `--include` option

## 0.1.5 (2017-08-14)

- Added support for non-`SELECT` queries
- Added `--pg-stat-statements` option
- Added advisory locks
- Added support for running as a non-superuser

## 0.1.4 (2017-07-02)

- Added support for multicolumn indexes

## 0.1.3 (2017-06-30)

- Fixed error with non-lowercase columns
- Fixed error with `json` columns

## 0.1.2 (2017-06-26)

- Added `--exclude` option
- Added `--log-sql` option

## 0.1.1 (2017-06-25)

- Added `--interval` option
- Added `--min-time` option
- Added `--log-level` option

## 0.1.0 (2017-06-24)

- Launched
