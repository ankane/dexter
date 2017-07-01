# Linux Packages

Distributions

- [Ubuntu 16.04 (Xenial)](#ubuntu-1604-xenial)
- [Ubuntu 14.04 (Trusty)](#ubuntu-1404-trusty)
- [Debian 8 (Jesse)](#debian-8-jesse)
- [CentOS / RHEL 7](#centos-rhel-7)
- [SUSE Linux Enterprise Server 12](#suse-linux-enterprise-server-12)

### Ubuntu 16.04 (Xenial)

```sh
wget -qO - https://deb.packager.io/key | sudo apt-key add -
echo "deb https://deb.packager.io/gh/pghero/dexter xenial master" | sudo tee /etc/apt/sources.list.d/dexter.list
sudo apt-get update
sudo apt-get -y install dexter
```

### Ubuntu 14.04 (Trusty)

```sh
wget -qO - https://deb.packager.io/key | sudo apt-key add -
echo "deb https://deb.packager.io/gh/pghero/dexter trusty master" | sudo tee /etc/apt/sources.list.d/dexter.list
sudo apt-get update
sudo apt-get install dexter
```

### Debian 8 (Jesse)

```sh
wget -qO - https://deb.packager.io/key | sudo apt-key add -
echo "deb https://deb.packager.io/gh/pghero/dexter jessie master" | sudo tee /etc/apt/sources.list.d/dexter.list
sudo apt-get update
sudo apt-get install dexter
```

### CentOS / RHEL 7

```sh
sudo rpm --import https://rpm.packager.io/key
echo "[dexter]
name=Repository for pghero/dexter application.
baseurl=https://rpm.packager.io/gh/pghero/dexter/centos7/master
enabled=1" | sudo tee /etc/yum.repos.d/dexter.repo
sudo yum install dexter
```

### SUSE Linux Enterprise Server 12

```sh
sudo rpm --import https://rpm.packager.io/key
sudo zypper addrepo "https://rpm.packager.io/gh/pghero/dexter/sles12/master" "dexter"
sudo zypper install dexter
```

## Credits

:heart: Made possible by [Packager](https://packager.io/)
