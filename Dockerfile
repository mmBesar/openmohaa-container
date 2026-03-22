# syntax=docker/dockerfile:1.4

FROM debian:trixie AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV CC=clang
ENV CXX=clang++

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates cmake ninja-build clang flex bison \
    libsdl2-dev libopenal-dev libcurl4-openssl-dev \
    zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

# Copy upstream source (provided as build context by CI)
COPY . /src
WORKDIR /src/build

RUN cmake -G Ninja \
    -DBUILD_NO_CLIENT=1 \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DTARGET_LOCAL_SYSTEM=1 \
    -DUSE_SYSTEM_LIBS=1 \
    -DCMAKE_INSTALL_PREFIX=/usr/local/games/openmohaa .. && \
    cmake --build . --target install

# --- Final image ---
FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive
ENV GAME_PORT=12203
ENV GAMESPY_PORT=12300

RUN apt-get update && apt-get install -y --no-install-recommends \
    socat libcurl4t64 libopenal1 libsdl2-2.0-0 util-linux tini ca-certificates && \
    groupadd -g 1000 openmohaa && useradd -u 1000 -g 1000 -m openmohaa && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/games/openmohaa /usr/local/games/openmohaa

# Entry script — find the dedicated server binary at build time so future
# upstream renames don't break the image
RUN BINARY=$(find /usr/local/games/openmohaa -name "omohaaded" -type f | head -n1) && \
    echo "Found binary at: $BINARY" && \
    printf '#!/bin/bash\nexec %s \\\n  +set fs_homepath home +set dedicated 2 \\\n  +set net_port ${GAME_PORT} +set net_gamespy_port ${GAMESPY_PORT} "$@"\n' \
    "$BINARY" > /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh

# Health check script
RUN printf '#!/bin/bash\nheader=$'"'"'\xff\xff\xff\xff\x01disconnect'"'"'\nmessage=$'"'"'none'"'"'\nquery_port=${GAME_PORT:-12203}\nwhile true; do\n  data=$(echo "$message" | socat - UDP:0.0.0.0:$query_port 2>/dev/null) && break\ndone\n[ "$data" = "$header" ] || exit 1\n' \
    > /usr/local/bin/health_check.sh && chmod +x /usr/local/bin/health_check.sh

VOLUME ["/usr/local/share/mohaa"]
WORKDIR /usr/local/share/mohaa

EXPOSE 12203/udp 12300/udp

HEALTHCHECK --interval=15s --timeout=20s --start-period=10s --retries=3 \
    CMD ["/usr/local/bin/health_check.sh"]

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
