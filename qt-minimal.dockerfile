# Global arguments
ARG APP_UID=1000
ARG APP_GID=1000

# Build stage
FROM docker.io/alpine AS build
ARG APP_VERSION \
  APP_OPENSSL_VERSION \
  TARGETARCH \
  TARGETVARIANT

RUN set -ex; \
  apk --no-cache --update add \
  git \
  curl \
  g++ \
  samurai \
  cmake \
  mesa-dev;

RUN set -ex; \
  curl -OL https://github.com/openssl/openssl/releases/download/openssl-${APP_OPENSSL_VERSION}/openssl-${APP_OPENSSL_VERSION}.tar.gz; \
  tar xzf openssl-${APP_OPENSSL_VERSION}.tar.gz;

RUN set -ex; \
  apk --update --no-cache add \
  perl \
  make \
  linux-headers;

RUN set -ex; \
  cd /openssl-${APP_OPENSSL_VERSION}; \
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
  esac; \
  make -s -j $(nproc) 2>&1 > /dev/null; \
  make -s -j $(nproc) install_sw 2>&1 > /dev/null;

RUN set -ex; \
  git clone --branch v${APP_VERSION} https://github.com/qt/qtbase.git;

RUN set -ex; \
  cd /qtbase; \
  ./configure \
  -static \
  -release \
  -prefix "/opt/qt" \
  -c++std c++17 \
  -nomake tests \
  -nomake examples \
  -no-feature-testlib \
  -no-gui \
  -no-dbus \
  -no-widgets \
  -no-feature-animation \
  -openssl \
  -openssl-linked \
  -optimize-size \
  -feature-optimize_full;

RUN set -ex; \
  cd /qtbase; \
  cmake --build . --parallel; \
  cmake --install .;

RUN set -ex; \
  git clone --branch v${APP_VERSION} https://github.com/qt/qttools.git;

RUN set -ex; \
  cd /qttools; \
  cmake -Wno-dev -B build -G Ninja \
  -DCMAKE_BUILD_TYPE="Release" \
  -DCMAKE_INSTALL_PREFIX="/opt/qt" \
  -DCMAKE_CXX_STANDARD=17 \
  -DCMAKE_PREFIX_PATH="/opt/qt" \
  -DCMAKE_EXE_LINKER_FLAGS="-static" \
  -DBUILD_SHARED_LIBS=OFF;

RUN set -ex; \
  cd /qttools; \
  cmake --build build; \
  cmake --install build;

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

COPY --from=build /opt/qt /opt/qt

USER ${APP_UID}:${APP_GID}
ENTRYPOINT ["/opt/qt/bin/qmake"]
CMD ["--version"]