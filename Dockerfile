# syntax=docker/dockerfile:1.4
ARG TARGETPLATFORM=linux/amd64
FROM --platform=${TARGETPLATFORM} debian:bookworm AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    git cmake ninja-build clang flex bison zlib1g-dev libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

ENV CC=clang
ENV CXX=clang++

WORKDIR /tmp/openmohaa
COPY . .

RUN mkdir build && cd build && \
    cmake -G Ninja \
        -DBUILD_NO_CLIENT=1 \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DTARGET_LOCAL_SYSTEM=1 \
        -DCMAKE_INSTALL_PREFIX=/usr/local/games/openmohaa \
        . && \
    cmake --build . --target install

# -------------------------
# Final runtime container
# -------------------------
FROM --platform=${TARGETPLATFORM} debian:bookworm AS final

RUN apt-get update && apt-get install -y --no-install-recommends \
    socat libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/games/openmohaa /usr/local/games/openmohaa

# MOHAA data goes here
VOLUME ["/usr/local/share/mohaa"]

COPY docker/server/base/health_check.sh /usr/local/bin/health_check.sh
RUN chmod +x /usr/local/bin/health_check.sh

RUN useradd -m openmohaa
USER openmohaa

COPY docker/server/base/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /usr/local/share/mohaa
EXPOSE 12203/udp 12300/udp

HEALTHCHECK --interval=15s --timeout=20s --start-period=10s --retries=3 \
  CMD [ "bash", "/usr/local/bin/health_check.sh" ]

ENTRYPOINT ["bash", "/usr/local/bin/entrypoint.sh"]
