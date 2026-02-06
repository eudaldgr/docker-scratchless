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
  boost-dev \
  g++ \
  git \
  make \
  miniupnpc-dev \
  openssl-dev \
  openssl \
  zlib-dev;

RUN set -ex; \
  git clone --branch ${APP_VERSION} https://github.com/PurpleI2P/i2pd.git;

RUN set -ex; \
  cd /i2pd; \
  make USE_UPNP=yes;

COPY --from=scratchless / ${APP_ROOT}/

RUN set -ex; \
  cd /i2pd; \
  mkdir -p "${APP_ROOT}"/lib; \
  install -D -m 755 i2pd "${APP_ROOT}"/bin/i2pd; \
  install -d -m 0755 -o ${APP_UID} -g ${APP_GID} "${APP_ROOT}"/usr/share/i2pd; \
  install -d -m 0700 -o ${APP_UID} -g ${APP_GID} "${APP_ROOT}"/var/lib/i2pd; \
  install -d -m 0755 -o ${APP_UID} -g ${APP_GID} "${APP_ROOT}"/var/log/i2pd; \
  install -D -m 644 contrib/tunnels.conf "${APP_ROOT}"/etc/i2pd/tunnels.conf; \
  install -D -m 644 contrib/docker/i2pd-docker.conf "${APP_ROOT}"/etc/i2pd/i2pd.conf; \
  cp -r contrib/certificates/ "${APP_ROOT}"/usr/share/i2pd/certificates; \
  ln -s /usr/share/i2pd/certificates "${APP_ROOT}"/var/lib/i2pd/certificates;

RUN set -ex; \
  sed -i 's/log = file/log = stdout/g' "${APP_ROOT}"/etc/i2pd/i2pd.conf; \
  sed -i 's/loglevel = none/loglevel = error/g' "${APP_ROOT}"/etc/i2pd/i2pd.conf;

RUN set -ex; \
  strip ${APP_ROOT}/bin/i2pd;

RUN set -ex; \
  ldd ${APP_ROOT}/bin/i2pd | awk '{if (match($3,"/")) print $3}' | xargs -I '{}' cp -v '{}' ${APP_ROOT}/lib/ || true;

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

EXPOSE 7070 4444 4447 7656 2827 7654 7650

USER ${APP_UID}:${APP_GID}
ENTRYPOINT ["/bin/i2pd", "--service"]
CMD ["--conf=/etc/i2pd/i2pd.conf", "--tunconf=/etc/i2pd/tunnels.conf", "--sam.enabled=true", "--sam.address=0.0.0.0", "--sam.port=7656", "--upnp.enabled=false"]