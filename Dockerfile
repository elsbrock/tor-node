# Dockerfile for Tor Relay Server with obfs4proxy (Multi-Stage build)
FROM golang AS go-build

ENV GOARCH=amd64

# Build /go/bin/obfs4proxy & /go/bin/meek-server
RUN go install -ldflags="-extldflags=-static" -v gitlab.com/yawning/obfs4.git/obfs4proxy@latest \
 && go install -ldflags="-extldflags=-static" -v git.torproject.org/pluggable-transports/meek.git/meek-server@latest \
 && cp -v /go/bin/linux_amd64/* /usr/local/bin

FROM amd64/archlinux AS tor
RUN pacman --noconfirm -Sy tor

RUN ldd /usr/bin/tor | tr -s '[:blank:]' '\n' | grep '^/' | \
    xargs -I % sh -xc 'mkdir -p $(dirname deps%); cp % deps%;'

FROM scratch AS stage

COPY --from=go-build /usr/local/bin/ /usr/bin/

COPY --from=tor /etc/passwd /etc/passwd
COPY --from=tor /usr/lib/libnss_dns.so.2 /usr/lib
COPY --from=tor /usr/lib/libresolv.so.2 /usr/lib
COPY --from=tor /etc/nsswitch.conf /etc/nsswitch.conf

COPY --from=tor /usr/bin/tor /usr/bin/
COPY --from=tor /deps /
COPY ./torrc /etc/tor/torrc

# Copy docker-entrypoint
COPY ./scripts/ /usr/local/bin/

FROM scratch

COPY --from=stage / /

# Persist data
VOLUME /etc/tor /var/lib/tor

# ORPort, DirPort, SocksPort, ObfsproxyPort, MeekPort
EXPOSE 9001 9030 9050 54444 7002

CMD ["tor", "-f", "/etc/tor/torrc"]

