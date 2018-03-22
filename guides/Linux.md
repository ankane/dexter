# Linux Packages

Distributions

- [Ubuntu 16.04 (Xenial)](#ubuntu-1604-xenial)
- [Ubuntu 14.04 (Trusty)](#ubuntu-1404-trusty)
- [Debian 9 (Stretch)](#debian-9-stretch)
- [Debian 8 (Jesse)](#debian-8-jesse)
- [CentOS / RHEL 7](#centos--rhel-7)
- [SUSE Linux Enterprise Server 12](#suse-linux-enterprise-server-12)

### Ubuntu 16.04 (Xenial)

```sh
wget -qO- https://dl.packager.io/srv/pghero/dexter/key | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/dexter.list \
  https://dl.packager.io/srv/pghero/dexter/master/installer/ubuntu/16.04.repo
sudo apt-get update
sudo apt-get -y install dexter
```

### Ubuntu 14.04 (Trusty)

```sh
wget -qO- https://dl.packager.io/srv/pghero/dexter/key | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/dexter.list \
  https://dl.packager.io/srv/pghero/dexter/master/installer/ubuntu/14.04.repo
sudo apt-get update
sudo apt-get install dexter
```

### Debian 9 (Stretch)

```sh
sudo apt-get -y install apt-transport-https
wget -qO- https://dl.packager.io/srv/pghero/dexter/key | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/dexter.list \
  https://dl.packager.io/srv/pghero/dexter/master/installer/debian/9.repo
sudo apt-get update
sudo apt-get install dexter
```

### Debian 8 (Jesse)

```sh
sudo apt-get -y install apt-transport-https
wget -qO- https://dl.packager.io/srv/pghero/dexter/key | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/dexter.list \
  https://dl.packager.io/srv/pghero/dexter/master/installer/debian/8.repo
sudo apt-get update
sudo apt-get install dexter
```

### CentOS / RHEL 7

```sh
sudo wget -O /etc/yum.repos.d/dexter.repo \
  https://dl.packager.io/srv/pghero/dexter/master/installer/el/7.repo
sudo yum install dexter
```

### SUSE Linux Enterprise Server 12

```sh
sudo wget -O /etc/zypp/repos.d/dexter.repo \
  https://dl.packager.io/srv/pghero/dexter/master/installer/sles/12.repo
sudo zypper install dexter
```

## Credits

:heart: Made possible by [Packager](https://packager.io/)
