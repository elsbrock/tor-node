## Tor Relay Server on Docker
[![Docker Image CI](https://github.com/elsbrock/tor-node/actions/workflows/docker-image.yml/badge.svg)](https://github.com/elsbrock/tor-node/actions/workflows/docker-image.yml)

#### A complete, efficient and secure Tor relay server Docker image
*This Docker image will run the latest version of Tor server available on Arch Linux. It will run Tor as an unprivileged regular user, as recommended by torproject.org.*

| Registry | Image Name |
|----------|------------|
| Docker Hub | else/tor-node |
| Container Registry | elsbrock/tor-node |

The image is distroless, meaning that it is missing a userland (using `FROM scratch`). This minimizes the attack surface and keeps the image extremely small. It also helps to keep the software updated. Whenever a new release of `tor` is published in Arch Linux, it will be automatically picked up.

Tor and its dependencies are kept up to date with the help of [Renovate](https://docs.renovatebot.com). PRs to update dependencies that pass the build are merged automatically and a new Docker image version is published subsequently.

> Releases are currently not automated, ie. the `:latest` tag is not updated automatically – if you want to follow `master`, use `:master`. Note that `:master` will be updated at least once per week, whereas `:latest` will only be updated every once in a while until automation is in place.

The Docker image can be automatically updated on the Docker host using [Watchtower](http://containrrr.dev/watchtower/).

#### About Tor

![Tor](https://media.torproject.org/image/official-images/2011-tor-logo-flat.svg "Tor logo")

The Tor network relies on volunteers to donate bandwidth. The more people who run relays, the faster the Tor network will be. If you have at least 2 megabits/s for both upload and download, please help out Tor by configuring your server to be a Tor relay too.

[Tor](https://www.torproject.org) is free software and an open network that helps you defend against
traffic analysis, a form of network surveillance that threatens personal
freedom and privacy, confidential business activities and relationships, and
state security.

- Tor prevents people from learning your location or browsing habits.
- Tor is for web browsers, instant messaging clients, and more.
- Tor is free and open source for Windows, Mac, Linux/Unix, and Android

### Quickstart - Tor relay server in minutes

- Prerequisites: A Linux server with Docker installed (see [Install Docker and Docker Compose](#install-docker-and-docker-compose) below)
- Public access to the configured ports

Create a directory for your Tor server data and your custom configuration. Then set your own Nickname (only letters and numbers) and an optional contact Email (which will be published on the Tor network):

```sh
docker run -d --init --name=tor-node --net=host --restart=always \
  -v tor-data:/var/lib/tor \
  else/tor-node
```

This command will run a Tor relay server with a safe default configuration (not as an exit node). Note though that this container is using the host network, ie. all ports are published by default on the host running the container.

The server will autostart after restarting the host system. All Tor data will be preserved in a Docker volume, even if you upgrade or remove the container. See below on how to backup the server identity.

Check with `docker logs -f tor-node`  If you see the message: `[notice] Self-testing indicates your ORPort is reachable from the outside. Excellent. Publishing server descriptor.` at the bottom after a while, your server started successfully. Then wait a bit longer and search for your server on the [Relay Search](https://metrics.torproject.org/rs.html).

### Customize Tor configuration
You may want to configure additional options to control your monthly data usage, or to run Tor as a hidden obfuscated bridge. Look at the Tor manual with all [Configuration File Options](https://www.torproject.org/docs/tor-manual.html.en).

For customisation you can create `*.conf` files in the `tor-config` volume containing valid Tor configuration directives. These directives are included from the main config located in `/etc/tor/torrc` which is is baked into the image.

*Example*

```
Nickname ieditedtheconfig
ContactInfo Random Person <random-person AT example dot com>

# Run Tor only as a server (no local applications)
SocksPort 0
ControlSocket 0
```

#### Run Tor with a mounted `torrc` configuration

To modify your Tor configuration, create another folder containing your configs and create a `*.conf` file, e.g.

```sh
mkdir -vp tor-config
nano tor-config/mynode.conf
```

Then mount your customized Tor config from the current directory of the host into the container with this command:
```
docker run -d --init --name=tor-node --net=host --restart=always \
  -v $PWD/tor-config:/etc/torrc.d:ro \
  -v tor-data:/var/lib/tor \
  else/tor-node
```

### Move or upgrade the Tor relay

When upgrading your Tor relay, or moving it on a different computer, it is important part to keep the same identity keys. Keeping backups of the identity keys so you can restore a relay in the future is the recommended way to ensure the reputation of the relay won't be wasted.

```
mkdir -vp tor-data/keys/ && \
docker cp tor-node:/var/lib/tor/keys/secret_id_key ./tor-data/keys/ && \
docker cp tor-node:/var/lib/tor/keys/ed25519_master_id_secret_key ./tor-data/keys/
```
You can also reuse these identity keys from a previous Tor relay server installation, to continue with the same Fingerprint and ID, by inserting the following lines, in the previous command:
```
-v $PWD/tor-data/keys/secret_id_key:/var/lib/tor/keys/secret_id_key \
-v $PWD/tor-data/keys/ed25519_master_id_secret_key:/var/lib/tor/ed25519_master_id_secret_key \
```

### Run Tor using docker-compose

Adapt the example `docker-compose.yml` with your settings or clone it from [Github](https://github.com/elsbrock/tor-node). By default it will start the tor node as well as a [Watchtower](https://containrrr.dev/watchtower/) instance to keep the container updated.

##### Configure and run the Tor relay server

- Configure the `docker-compose.yml` and optionally the custom config file with your individual settings. Possibly install `git` first.
```
cd /opt && git clone https://github.com/elsbrock/tor-node.git && cd tor-node
nano docker-compose.yml
```

- Start a new instance of the Tor relay server and display the logs.
```
docker-compose up -d
docker-compose logs -f
```

No commands can be executed inside the container since it is missing a userland. You can expose the ControlPort via a custom config to connect from other containers to it.

### Run Tor relay with IPv6

If your host supports IPv6, please enable it! The host system needs to have IPv6 activated. From your host server try to ping any IPv6 host: `ping6 google.com` Then find out your external IPv6 address with this command (from dnsutils):

`dig +short -6 myip.opendns.com aaaa @resolver1.ipv6-sandbox.opendns.com`

If that works fine, activate IPv6 for Docker by adding the following to the file `daemon.json` on the docker host and restarting Docker.

- use the IPv6 subnet/64 address from your provider for `fixed-cidr-v6`

```
nano /etc/docker/daemon.json

    {
    "ipv6": true,
    "fixed-cidr-v6": "21ch:ange:this:addr::/64"
    }

systemctl restart docker && systemctl status docker
```

The sample Tor relay server configurations use `network_mode: host` which makes it easier to use IPv6.

- Next make your Tor relay reachable via IPv6 by adding the applicable IPv6 address at the ORPort line in your custom Tor configuration:

```
nano tor-config/mynode.conf
# should contain
# ORPort [IPv6-address]:9001`
```

- Restart the container and test, that the Tor relay can reach the outside world:
```
docker-compose restart
docker-compose logs
```

You should see something like this in the log: `[notice] Opening OR listener on [2200:2400:4400:4a61:5400:4ff:f444:e448]:9001`

- IPv6 info for Tor and Docker:
    1. [A Tor relay operators IPv6 HOWTO](https://trac.torproject.org/projects/tor/wiki/doc/IPv6RelayHowto)
    2. [Walkthrough: Enabling IPv6 Functionality for Docker & Docker Compose](http://collabnix.com/enabling-ipv6-functionality-for-docker-and-docker-compose/)
    3. [Basic Configuration of Docker Engine with IPv6](http://www.debug-all.com/?p=128)
    4. [Docker, IPv6 and –net=”host”](http://www.debug-all.com/?p=163)
    5. [Docker Networking 101 – Host mode](http://www.dasblinkenlichten.com/docker-networking-101-host-mode/)
    5. When using the host network driver for a container, that container’s network stack is not isolated from the Docker host. If you run a container which binds to port 9001 and you use host networking, the container’s application will be available on port 9001 on the host’s IP address.

---

### Install Docker and Docker Compose

Links how to install

- [Docker](https://docs.docker.com/install/)
- [Docker Compose](https://docs.docker.com/compose/install/)

After the installation process is finished, you may need to enable the service and make sure it is started (e.g. CentOS).

```
systemctl enable docker
systemctl start docker
```

Please use the latest Docker engine available (do not use the possibly outdated engine that ships with your distro's repository).

### Guides

- [Tor Relay Guide](https://trac.torproject.org/projects/tor/wiki/TorRelayGuide)
- [Tor on Debian Installation Instructions 2019](https://2019.www.torproject.org/docs/debian.html.en)
- [Torproject - git repo](https://github.com/torproject/tor)

### License
 - MIT

### Credits
Credits go out to
- [chriswayg/tor-server](https://github.com/chriswayg/tor-server) used as the basis for this image
- Arch Linux [Tor package](https://github.com/chriswayg/tor-server) 
