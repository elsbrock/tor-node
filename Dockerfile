FROM golang@sha256:5eb58ca0a747ed2e2f4e069d1116badb02a172cf160d31f801776a2342c12863 AS go-build

ENV GOARCH=amd64
RUN go install -ldflags="-extldflags=-static" -v gitlab.com/yawning/obfs4.git/obfs4proxy@latest \
 && cp -v /go/bin/* /usr/local/bin

FROM amd64/archlinux@sha256:fbd5fa7bb3380380aef04c8377745e7254c705a38c8ef55446e398df36762ba0 AS install-tor
RUN pacman --noconfirm -Sy tor

RUN sed -i 's/#%include/%include/' /etc/tor/torrc && \
    sed -i 's/Log notice syslog/#Log notice syslog/' /etc/tor/torrc && \
    sed -i 's/#ORPort 9001/ORPort 9001/' /etc/tor/torrc && \
    sed -i 's/#DirPort 9030/DirPort 9030/' /etc/tor/torrc && \
    sed -i 's/#ExitPolicy reject \\*:\\*/ExitPolicy reject *:*/' /etc/tor/torrc

RUN mkdir /etc/torrc.d

RUN ldd /usr/bin/tor | tr -s '[:blank:]' '\n' | grep '^/' | \
    xargs -I % sh -xc 'mkdir -p $(dirname deps%); cp -L % deps%;'

FROM scratch AS stage

COPY --from=go-build /usr/local/bin/ /usr/bin/

COPY --from=install-tor /etc/passwd /etc/group /etc/
COPY --from=install-tor \
    /usr/lib/libnss_files-2.33.so /usr/lib/libnss_files.so /usr/lib/libnss_files.so.2 \
    /usr/lib/libnss_compat-2.33.so /usr/lib/libnss_compat.so /usr/lib/libnss_compat.so.2 \
    /usr/lib/libresolv-2.33.so /usr/lib/libresolv.so /usr/lib/libresolv.so.2 \
    /usr/lib/libnss_dns-2.33.so /usr/lib/libnss_dns.so /usr/lib/libnss_dns.so.2 \
    /usr/lib/
COPY --from=install-tor /etc/nsswitch.conf /etc/nsswitch.conf

COPY --from=install-tor /usr/bin/tor /usr/bin/
COPY --from=install-tor /deps /
COPY --from=install-tor /etc/tor/torrc /etc/tor/torrc
COPY --from=install-tor --chown=tor:tor /var/lib/tor /var/lib/tor

FROM scratch

COPY --from=stage / /

VOLUME /etc/torrc.d /var/lib/tor
EXPOSE 9001 9030

ENTRYPOINT ["/usr/bin/tor"]
CMD ["-f", "/etc/tor/torrc"]

