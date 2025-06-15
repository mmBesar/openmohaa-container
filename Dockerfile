# syntax=docker/dockerfile:1.4

ARG TARGETPLATFORM=linux/amd64
FROM --platform=${TARGETPLATFORM} debian:bookworm AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV CC=clang
ENV CXX=clang++

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates git cmake ninja-build clang flex bison \
    zlib1g-dev libcurl4-openssl-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/openmohaa
RUN git clone --depth 1 --branch main https://github.com/openmoh/openmohaa.git src

WORKDIR /tmp/openmohaa/build
RUN cmake -G Ninja \
    -DBUILD_NO_CLIENT=1 \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DTARGET_LOCAL_SYSTEM=1 \
    -DCMAKE_INSTALL_PREFIX=/usr/local/games/openmohaa ../src && \
    cmake --build . --target install

# --- Final image ---
FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV GAME_PORT=12203
ENV GAMESPY_PORT=12300

RUN apt-get update && apt-get install -y --no-install-recommends \
    socat libcurl4-openssl-dev util-linux tini ca-certificates && \
    groupadd -g 1000 openmohaa && useradd -u 1000 -g 1000 -m openmohaa && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/games/openmohaa /usr/local/games/openmohaa

# Entry script
RUN echo '#!/bin/bash\n\
exec /usr/local/games/openmohaa/lib/openmohaa/omohaaded \\\n\
  +set fs_homepath home +set dedicated 2 \\\n\
  +set net_port ${GAME_PORT} +set net_gamespy_port ${GAMESPY_PORT} "$@"' \
> /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

# Health check script
RUN echo '#!/bin/bash\n\
header=$'\''\xff\xff\xff\xff\x01disconnect'\''\n\
message=$'\''none'\''\n\
query_port=${GAME_PORT:-12203}\n\
while true; do\n\
  data=$(echo "$message" | socat - UDP:0.0.0.0:$query_port 2>/dev/null) && break\n\
done\n\
[ "$data" = "$header" ] || exit 1' \
> /usr/local/bin/health_check.sh && chmod +x /usr/local/bin/health_check.sh

VOLUME ["/usr/local/share/mohaa"]
WORKDIR /usr/local/share/mohaa

EXPOSE 12203/udp 12300/udp
HEALTHCHECK --interval=15s --timeout=20s --start-period=10s --retries=3 \
  CMD ["/usr/local/bin/health_check.sh"]

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
