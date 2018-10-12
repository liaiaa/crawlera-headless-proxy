###############################################################################
# BUILD STAGE

FROM golang:1-alpine AS build-env

RUN set -x \
  && apk --no-cache --update add \
    bash \
    git \
    make

COPY . /app

RUN set -x \
  && cd /app \
  && make static


###############################################################################
# TLS STAGE

FROM alpine AS tls-env

RUN set -x \
  && apk --no-cache --update add ca-certificates \
  && wget -O /usr/local/share/ca-certificates/crawlera-ca.crt https://doc.scrapinghub.com/_downloads/crawlera-ca.crt \
  && sha1sum /usr/local/share/ca-certificates/crawlera-ca.crt | cut -f1 -d' ' | \
  while read -r sum _; do \
    if [ "${sum}" != "5798e59f6f7ecad3c0e1284f42b07dcaa63fbd37" ]; then \
      echo "Incorrect CA certificate checksum ${sum}"; \
      exit 1; \
  fi; done

COPY ca.crt /usr/local/share/ca-certificates/own-cert.crt

RUN set -x && \
  update-ca-certificates


###############################################################################
# PACKAGE STAGE

FROM scratch

ENTRYPOINT ["/crawlera-headless-proxy"]
ENV CRAWLERA_HEADLESS_BINDIP=0.0.0.0 \
    CRAWLERA_HEADLESS_BINDPORT=3128 \
    CRAWLERA_HEADLESS_PROXYAPIIP=0.0.0.0 \
    CRAWLERA_HEADLESS_PROXYAPIPORT=3130 \
    CRAWLERA_HEADLESS_CONFIG=/config.toml
EXPOSE 3128 3130

COPY --from=tls-env \
  /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build-env \
  /app/crawlera-headless-proxy \
  /app/config.toml \
  /
