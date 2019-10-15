# Dante socks proxy server

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/akmaslov-dev/dante-proxy-server/blob/master/LICENSE.txt)

## Main Info

Scripts for automated `dante socks proxy server` installation

Versatile setup script for `Ubuntu`, `Debian` and `CentOS` releases

Dante socks proxy server version - `1.4.2`

Official Dante proxy server page - <https://www.inet.no/dante/>

____

## Install and configuration section

Run this code in your terminal and follow the instructions:

```bash
wget https://git.io/Je81F -O install.sh && bash install.sh
```

or clone this project at first and then:

```bash
cd dante-proxy-server && bash install.sh
```

### Additional options

You can run this script again to:

 1. Add new user for proxy
 2. Remove an existing user
 3. Remove Dante socks proxy server

```bash
bash install.sh
```

____

## Useful tips and tricks

Manual sockd options for Ubuntu and Debian `start`,  `stop`, `restart`, `status`

```bash
/etc/init.d/{PARAM_HERE}
```

Manual sockd options for CentOS `start`,  `stop`, `restart`, `status`

```bash
service sockd {PARAM_HERE}
```

Port, interface, auth metod, ipv4\ipv6 support and other cool options contains here

```bash
/etc/sockd.conf
```
