# Global arguments
ARG APP_UID=1000
ARG APP_GID=1000

# Setup stage
FROM docker.io/alpine AS builder
ARG TARGETARCH
ARG APP_ROOT
ARG APP_VERSION
USER root

RUN set -ex; \
  mkdir -p ${APP_ROOT}/{etc,run,tmp};

RUN set -ex; \
  printf "%s\n" \
  "root:x:0:0:root:/root:/sbin/nologin" \
  "docker:x:1000:1000:docker:/:/sbin/nologin" \
  > ${APP_ROOT}/etc/passwd;

RUN set -ex; \
  printf "%s\n" \
  "root:x:0:root" \
  "docker:x:1000:docker" \
  > ${APP_ROOT}/etc/group;

RUN set -ex; \
  apk --no-cache --update --repository https://dl-cdn.alpinelinux.org/alpine/edge/main add \
  ca-certificates; \
  mkdir -p ${APP_ROOT}/usr/share/ca-certificates; \
  mkdir -p ${APP_ROOT}/etc/ssl/certs; \
  cp -R /usr/share/ca-certificates/* ${APP_ROOT}/usr/share/ca-certificates; \
  cp -R /etc/ssl/certs/* ${APP_ROOT}/etc/ssl/certs;

RUN set -ex; \
  apk --no-cache --update --repository https://dl-cdn.alpinelinux.org/alpine/edge/main add \
  tzdata; \
  mkdir -p ${APP_ROOT}/usr/share/zoneinfo; \
  cp -R /usr/share/zoneinfo/* ${APP_ROOT}/usr/share/zoneinfo;

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
  APP_GID

COPY --from=builder ${APP_ROOT}/ /

USER ${APP_UID}:${APP_GID}
ENTRYPOINT ["/"]