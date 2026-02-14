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
  apk --no-cache --update add \
  cmake \
  g++ \
  make \
  samurai;

RUN set -ex; \
  wget -qO- "https://github.com/nicolas-van/multirun/archive/${APP_VERSION}.tar.gz" | tar xz;

RUN set -ex; \
  cd /multirun-${APP_VERSION}; \
  cmake -B build \
  -DCMAKE_BUILD_TYPE=None \
  -DCMAKE_INSTALL_PREFIX=/usr \
  .;

RUN set -ex; \
  cd /multirun-${APP_VERSION}; \
  cmake --build build;

COPY --from=scratchless / ${APP_ROOT}/

RUN set -ex; \
  cd /multirun-${APP_VERSION}; \
  install -D -m 755 build/multirun "${APP_ROOT}"/bin/multirun;

RUN set -ex; \
  strip ${APP_ROOT}/bin/multirun;

RUN set -ex; \
  mkdir -p "${APP_ROOT}"/lib; \
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
ENTRYPOINT ["/bin/multirun"]
CMD ["-h"]