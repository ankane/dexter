## 0.3.2 [unreleased]

- Fixed issue with multiline queries in csv format

## 0.3.1

- Added support for queries with bind variables
- Fixed error with streaming logs as csv format
- Handle malformed CSV gracefully

## 0.3.0

- Added support for schemas
- Added support for csv format
- Added `--analyze` option and do not analyze by default
- Added `--min-calls` option
- Fixed debug output when indexes not found

## 0.2.1

- Fixed bad suggestions
- Improved debugging output

## 0.2.0

- Added same connection options as `psql`
- Added support for multiple files
- Added `error` log level
- Better error messages when cannot connect

Breaking

- `-h` option changed to `--host` instead of `--help` for consistency with `psql`

## 0.1.6

- Significant performance improvements
- Added `--include` option

## 0.1.5

- Added support for non-`SELECT` queries
- Added `--pg-stat-statements` option
- Added advisory locks
- Added support for running as a non-superuser

## 0.1.4

- Added support for multicolumn indexes

## 0.1.3

- Fixed error with non-lowercase columns
- Fixed error with `json` columns

## 0.1.2

- Added `--exclude` option
- Added `--log-sql` option

## 0.1.1

- Added `--interval` option
- Added `--min-time` option
- Added `--log-level` option

## 0.1.0

- Launched
