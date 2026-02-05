# Global arguments
ARG APP_UID=1000
ARG APP_GID=1000

FROM ghcr.io/eudaldgr/scratchless AS scratchless

# Build stage
FROM docker.io/alpine AS build
ARG APP_VERSION \
  APP_ROOT \
  TARGETARCH \
  TARGETVARIANT

RUN set -ex; \
  apk --update --no-cache add \
  perl \
  g++ \
  make \
  linux-headers \
  git \
  cmake \
  build-base \
  samurai \
  python3 \
  py3-pkgconfig \
  pkgconfig;

RUN set -ex; \
  curl -OL https://github.com/openssl/openssl/releases/download/openssl-${APP_VERSION}/openssl-${APP_VERSION}.tar.gz; \
  tar xzf openssl-${APP_VERSION}.tar.gz;

RUN set -ex; \
  cd /openssl-${APP_VERSION}; \
  case "${TARGETARCH}${TARGETVARIANT}" in \
  "amd64"|"arm64") \
  ./Configure \
  -static \
  --openssldir=/etc/ssl; \
  ;; \
  \
  "armv7") \
  ./Configure \
  linux-generic32 \
  -static \
  --openssldir=/etc/ssl; \
  ;; \
  esac;

RUN set -ex; \
  cd /openssl-${APP_VERSION}; \
  make -s -j $(nproc) 2>&1 > /dev/null;

COPY --from=scratchless / ${APP_ROOT}/

RUN set -ex; \
  mkdir -p ${APP_ROOT}/usr/local/bin; \
  cp /openssl-${APP_VERSION}/apps/openssl ${APP_ROOT}/usr/local/bin;

RUN set -ex; \
  mkdir -p ${APP_ROOT}/etc/ssl; \
  cp /openssl-${APP_VERSION}/apps/openssl.cnf ${APP_ROOT}/etc/ssl;

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
ENTRYPOINT ["/usr/local/bin/openssl"]
CMD ["--version"]