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
  --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing \
  binutils \
  nss-tools;

COPY --from=scratchless / ${APP_ROOT}/

RUN set -ex; \
  mkdir -p ${APP_ROOT}/bin ${APP_ROOT}/lib; \
  install -m 755 /usr/bin/certutil ${APP_ROOT}/bin/certutil;

RUN set -ex; \
  strip ${APP_ROOT}/bin/certutil;

RUN set -ex; \
  ldd ${APP_ROOT}/bin/certutil | awk '{if (match($3,"/")) print $3}' | xargs -I '{}' cp -v '{}' ${APP_ROOT}/lib/ || true;

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

USER ${APP_UID}:${APP_GID}
ENTRYPOINT ["/bin/certutil"]
CMD ["--help"]