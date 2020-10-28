# Linux Packages

- [Ubuntu](#ubuntu)
- [Debian](#debian)
- [CentOS / RHEL](#centos--rhel)
- [SUSE Linux Enterprise Server](#suse-linux-enterprise-server)

### Ubuntu

```sh
wget -qO- https://dl.packager.io/srv/pghero/dexter/key | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/dexter.list \
  https://dl.packager.io/srv/pghero/dexter/master/installer/ubuntu/$(. /etc/os-release && echo $VERSION_ID).repo
sudo apt-get update
sudo apt-get -y install dexter
```

Supports Ubuntu 20.04 (Focal), 18.04 (Bionic), and 16.04 (Xenial)

### Debian

```sh
sudo apt-get -y install apt-transport-https
wget -qO- https://dl.packager.io/srv/pghero/dexter/key | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/dexter.list \
  https://dl.packager.io/srv/pghero/dexter/master/installer/debian/$(. /etc/os-release && echo $VERSION_ID).repo
sudo apt-get update
sudo apt-get -y install dexter
```

Supports Debian 10 (Buster), 9 (Stretch), and 8 (Jesse)

### CentOS / RHEL

```sh
sudo wget -O /etc/yum.repos.d/dexter.repo \
  https://dl.packager.io/srv/pghero/dexter/master/installer/el/$(. /etc/os-release && echo $VERSION_ID).repo
sudo yum -y install dexter
```

Supports CentOS / RHEL 8 and 7

### SUSE Linux Enterprise Server

```sh
sudo wget -O /etc/zypp/repos.d/dexter.repo \
  https://dl.packager.io/srv/pghero/dexter/master/installer/sles/12.repo
sudo zypper install dexter
```

Supports SUSE Linux Enterprise Server 12

## Credits

:heart: Made possible by [Packager](https://packager.io/)
