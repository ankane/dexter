# Hosted Postgres

Some hosted providers like Heroku do not support the HypoPG extension, which Dexter needs to run. Hopefully this will change with time. For now, we can spin up a separate database instance to run Dexter. It’s not super convenient, but can be useful to do from time to time.

### Install Postgres and Ruby

Ubuntu 22.04

```sh
sudo apt-get install -y curl ca-certificates gnupg
curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null
sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
sudo apt-get update
sudo apt-get install -y postgresql-15 postgresql-server-dev-15
sudo -u postgres createuser $(whoami) -s
sudo apt-get install -y ruby3.0 ruby3.0-dev
```

Mac

```sh
brew install postgresql
brew install ruby
```

### Install HypoPG and Dexter

HypoPG

```sh
cd /tmp
curl -L https://github.com/HypoPG/hypopg/archive/1.4.0.tar.gz | tar xz
cd hypopg-1.4.0
make
make install # may need sudo
```

Dexter

```sh
gem install pgdexter # may need sudo
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
