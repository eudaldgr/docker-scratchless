# Global arguments
ARG APP_UID=1000
ARG APP_GID=1000

FROM ghcr.io/eudaldgr/scratchless AS scratchless

# Build stage
FROM docker.io/alpine AS build
ARG APP_VERSION \
  APP_ROOT \
  APP_UID \
  APP_GID \
  TARGETARCH \
  TARGETVARIANT

RUN set -ex; \
  apk --no-cache --update add \
  ca-certificates \
  curl \
  g++ \
  libcap-dev \
  libevent-dev \
  libseccomp-dev \
  linux-headers \
  make \
  openssl-dev \
  xz-dev \
  zlib-dev \
  zstd-dev;

RUN set -ex; \
  curl -OL https://www.torproject.org/dist/tor-${APP_VERSION}.tar.gz;

RUN set -ex; \
  tar xzf tor-${APP_VERSION}.tar.gz;

RUN set -ex; \
  cd /tor-${APP_VERSION}; \
  ./configure \
  --prefix=/usr \
  --sysconfdir=/etc \
  --localstatedir=/var \
  --enable-gpl \
  --disable-manpage \
  --disable-html-manual \
  --disable-asciidoc;

RUN set -ex; \
  cd /tor-${APP_VERSION}; \
  make -j$(nproc) 2>&1 > /dev/null;

COPY --from=scratchless / ${APP_ROOT}/

RUN set -ex; \
  cd /tor-${APP_VERSION}; \
  mkdir -p ${APP_ROOT}/bin ${APP_ROOT}/lib; \
  install -m 755 src/app/tor ${APP_ROOT}/bin/tor; \
  install -m 755 src/tools/tor-resolve ${APP_ROOT}/bin/tor-resolve; \
  install -m 755 src/tools/tor-print-ed-signing-cert ${APP_ROOT}/bin/tor-print-ed-signing-cert; \
  install -m 755 src/tools/tor-gencert ${APP_ROOT}/bin/tor-gencert;

RUN set -ex; \
  strip ${APP_ROOT}/bin/tor; \
  strip ${APP_ROOT}/bin/tor-resolve; \
  strip ${APP_ROOT}/bin/tor-print-ed-signing-cert; \
  strip ${APP_ROOT}/bin/tor-gencert;

RUN set -ex; \
  install -d -m 0700 -o ${APP_UID} -g ${APP_GID} "${APP_ROOT}"/var/lib/tor; \
  install -d -m 0755 -o ${APP_UID} -g ${APP_GID} "${APP_ROOT}"/var/log/tor; \
  install -d -m 0755 -o ${APP_UID} -g ${APP_GID} "${APP_ROOT}"/run/tor;

RUN set -ex; \
  ldd ${APP_ROOT}/bin/tor | awk '{if (match($3,"/")) print $3}' | xargs -I '{}' cp -v '{}' ${APP_ROOT}/lib/ || true;

RUN set -ex; \
  cp /lib/ld-musl-*.so.1 ${APP_ROOT}/lib/;

# Final scratch image
FROM scratch

ARG TARGETPLATFORM \
  TARGETOS \
  TARGETARCH \
  TARGETVARIANT \
  APP_IMAGE \
  APP_NAME \
  APP_VERSION \
  APP_ROOT \
  APP_UID \
  APP_GID \
  APP_NO_CACHE

ENV APP_IMAGE=${APP_IMAGE} \
  APP_NAME=${APP_NAME} \
  APP_VERSION=${APP_VERSION} \
  APP_ROOT=${APP_ROOT}

COPY --from=build ${APP_ROOT}/ /

ENV HOME=/var/lib/tor

EXPOSE 9050 9051

USER ${APP_UID}:${APP_GID}
ENTRYPOINT ["/bin/tor"]
CMD ["--runasdaemon", "1", "--DataDirectory", "/var/lib/tor"]