# Linux Packages

- [Ubuntu](#ubuntu)
- [Debian](#debian)

### Ubuntu

```sh
wget -qO- https://dl.packager.io/srv/pghero/dexter/key | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/dexter.list \
  https://dl.packager.io/srv/pghero/dexter/master/installer/ubuntu/$(. /etc/os-release && echo $VERSION_ID).repo
sudo apt-get update
sudo apt-get -y install dexter
```

Supports Ubuntu 22.04 (Jammy)

### Debian

```sh
sudo apt-get -y install apt-transport-https
wget -qO- https://dl.packager.io/srv/pghero/dexter/key | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/dexter.list \
  https://dl.packager.io/srv/pghero/dexter/master/installer/debian/$(. /etc/os-release && echo $VERSION_ID).repo
sudo apt-get update
sudo apt-get -y install dexter
```

Supports Debian 11 (Bullseye)

## Credits

:heart: Made possible by [Packager](https://packager.io/)
