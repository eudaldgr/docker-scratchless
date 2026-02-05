# Global arguments
ARG APP_UID=1000
ARG APP_GID=1000

# Build stage
FROM docker.io/alpine AS build
ARG APP_VERSION \
  APP_ROOT \
  TARGETARCH \
  TARGETVARIANT

RUN set -ex; \
  apk --no-cache --update add \
  bash \
  clang \
  git \
  linux-headers \
  make \
  perl \
  snappy-dev;

RUN set -ex; \
  git clone --branch v${APP_VERSION} https://github.com/facebook/rocksdb.git /rocksdb;

RUN set -ex; \
  cd /rocksdb; \
  sed 's/install -C/install -c/g' Makefile > _; \
  mv -f _ Makefile;

RUN set -ex; \
  cd /rocksdb; \
  PORTABLE=1 \
  DISABLE_JEMALLOC=1 \
  DEBUG_LEVEL=0 \
  USE_RTTI=1 \
  make static_lib;

RUN set -ex; \
  cd /rocksdb; \
  PREFIX=${APP_ROOT}/usr \
  make install-static;

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

USER ${APP_UID}:${APP_GID}