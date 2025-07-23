# Hosted Postgres

Some hosted providers like Heroku do not support the HypoPG extension, which Dexter needs to run. Hopefully this will change with time. For now, we can spin up a separate database instance to run Dexter. It’s not super convenient, but can be useful to do from time to time.

### Install Postgres, HypoPG, and Dexter

Ubuntu

```sh
sudo apt-get install -y postgresql-common
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
sudo apt-get install -y postgresql-17 postgresql-17-hypopg
sudo service postgresql start
sudo -u postgres createuser $(whoami) -s
sudo apt-get install -y build-essential libpq-dev ruby ruby-dev
sudo gem install pgdexter
```

Mac

```sh
brew install postgresql@17 hypopg dexter
```

### Download logs

#### Heroku

Production-tier databases only

```sh
heroku logs -p postgres > postgresql.log
```

### Dump and restore

We recommend creating a new instance from a snapshot for the dump to avoid affecting customers.

```sh
pg_dump -v -j 8 -Fd -f /tmp/newout.dir <connection-options>
```

Then shutdown the dump instance. Restore with:

```sh
createdb dexter_restore
pg_restore -v -j 8 -x -O --format=d -d dexter_restore /tmp/newout.dir/
```

### Run Dexter

```sh
dexter dexter_restore postgresql.log* --analyze
```

:tada:
