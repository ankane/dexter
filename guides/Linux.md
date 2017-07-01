# Linux Packages

Distributions

- [Ubuntu 16.04 (Xenial)](#ubuntu-1604-xenial)

### Ubuntu 16.04 (Xenial)

```sh
wget -qO - https://deb.packager.io/key | sudo apt-key add -
echo "deb https://deb.packager.io/gh/pghero/dexter xenial master" | sudo tee /etc/apt/sources.list.d/dexter.list
sudo apt-get update
sudo apt-get -y install dexter
```
