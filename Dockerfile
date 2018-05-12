# Dockerfile for Tor Relay Server with obfs4proxy

FROM debian:stretch-slim
MAINTAINER Christian chriswayg@gmail.com

# Environment setting only used during build
ARG DEBIAN_FRONTEND=noninteractive

# If no Nickname is set, a random string will be added to 'Tor4'
ENV TOR_USER=debian-tor \
    TOR_NICKNAME=Tor4 \
    TERM=xterm

# Install prerequisites
RUN apt-get update &&  \
	apt-get install --no-install-recommends --no-install-suggests -y \
      golang \
      git \
      apt-transport-https \
      ca-certificates \
      dirmngr \
      apt-utils \
      pwgen \
      gnupg && \
  # Add torproject.org Debian repository, which will always install the latest stable version
	GPGKEY=A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89; \
	found=''; \
	for server in \
  		ha.pool.sks-keyservers.net \
  		hkp://keyserver.ubuntu.com:80 \
  		hkp://p80.pool.sks-keyservers.net:80 \
      ipv4.pool.sks-keyservers.net \
      keys.gnupg.net \
  		pgp.mit.edu \
	; do \
		echo "Fetching GPG key $GPGKEY from $server"; \
		APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE="True" apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPGKEY" && found=yes && break; \
	done; \
	test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPGKEY" && exit 1; \
  apt-get clean && rm -rf /var/lib/apt/lists/* && \
  \
  echo "deb https://deb.torproject.org/torproject.org stretch main"   >  /etc/apt/sources.list.d/tor-apt-sources.list && \
  echo "deb-src https://deb.torproject.org/torproject.org stretch main" >> /etc/apt/sources.list.d/tor-apt-sources.list && \
  echo "deb http://deb.torproject.org/torproject.org obfs4proxy main" >> /etc/apt/sources.list.d/tor-apt-sources.list && \
# Install tor and obfs4proxy & backup torrc
  apt-get update && \
  apt-get install --no-install-recommends --no-install-suggests -y \
    iputils-ping \
    tor \
    deb.torproject.org-keyring && \
  mv -v /etc/tor/torrc /etc/tor/torrc.default \
    # Install obfs4proxy & meek-server
    && export GOPATH="/tmp/go" \
    && go get -v git.torproject.org/pluggable-transports/obfs4.git/obfs4proxy \
    && mv -v /tmp/go/bin/obfs4proxy /usr/local/bin/ \
    && rm -rf /tmp/go \
    && go get -v git.torproject.org/pluggable-transports/meek.git/meek-server \
    && mv -v /tmp/go/bin/meek-server /usr/local/bin/ \
    && rm -rf /tmp/go && \
  # Download GeoIP files
  cd /usr/share/tor && \
  apt-get -d source tor && \
  tar --strip-components=3 --wildcards -zxvf tor_*.orig.tar.gz tor-*/src/config/geoip && \
  tar --strip-components=3 --wildcards -zxvf tor_*.orig.tar.gz tor-*/src/config/geoip6 && \
  rm -v tor_* && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Debian creates an unprivileged tor user: debian-tor

# Copy Tor configuration file
COPY ./torrc /etc/tor/torrc

# Copy docker-entrypoint
COPY ./scripts/ /usr/local/bin/

# Persist data
VOLUME /etc/tor /var/lib/tor

# ORPort, DirPort, SocksPort, ObfsproxyPort, MeekPort
EXPOSE 9001 9030 9050 54444 7002

ENTRYPOINT ["docker-entrypoint"]

CMD ["tor", "-f", "/etc/tor/torrc"]
