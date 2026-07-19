# Linux Packages

- [Ubuntu](#ubuntu)
- [Debian](#debian)

### Ubuntu

```sh
sudo apt-get -y install gnupg wget
wget -qO- https://dl.packager.io/srv/pghero/dexter/key | gpg -o /etc/apt/keyrings/dexter-archive-keyring.pgp --dearmor
echo "deb [signed-by=/etc/apt/keyrings/dexter-archive-keyring.pgp] https://dl.packager.io/srv/deb/pghero/dexter/master/ubuntu $(. /etc/os-release && echo $VERSION_ID) main" | sudo tee /etc/apt/sources.list.d/dexter.list
sudo apt-get update
sudo apt-get -y install dexter
```

Supports Ubuntu 22.04 (Jammy) and 24.04 (Noble)

### Debian

```sh
sudo apt-get -y install apt-transport-https gnupg wget
sudo mkdir -p /etc/apt/keyrings
wget -qO- https://dl.packager.io/srv/pghero/dexter/key | gpg -o /etc/apt/keyrings/dexter-archive-keyring.pgp --dearmor
echo "deb [signed-by=/etc/apt/keyrings/dexter-archive-keyring.pgp] https://dl.packager.io/srv/deb/pghero/dexter/master/debian $(. /etc/os-release && echo $VERSION_ID) main" | sudo tee /etc/apt/sources.list.d/dexter.list
sudo apt-get update
sudo apt-get -y install dexter
```

Supports Debian 11 (Bullseye) and 12 (Bookworm)

## Credits

:heart: Made possible by [Packager](https://packager.io/)
