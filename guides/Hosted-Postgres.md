# Hosted Postgres

Some hosted providers like Amazon RDS and Heroku do not support the HypoPG extension, which Dexter needs to run. Hopefully this will change with time. For now, we can spin up a separate database instance to run Dexter. It’s not super convenient, but can be useful to do from time to time.

### Install Postgres and Ruby

Linux

```sh
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
sudo apt-get install -y wget ca-certificates
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get install -y postgresql-9.6 postgresql-server-dev-9.6
sudo -u postgres createuser $(whoami) -s
sudo apt-get install -y ruby2.2 ruby2.2-dev
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
curl -L https://github.com/dalibo/hypopg/archive/1.0.0.tar.gz | tar xz
cd hypopg-1.0.0
make
make install # may need sudo
```

Dexter

```sh
gem install pgdexter # may need sudo
```

### Download logs

#### Amazon RDS

Create an IAM user with the policy below:

```
{
  "Statement": [
    {
      "Action": [
        "rds:DescribeDBLogFiles",
        "rds:DownloadDBLogFilePortion"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
```

And run:

```sh
aws configure
gem install pghero_logs # may need sudo
pghero_logs download <instance-id>
```

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
