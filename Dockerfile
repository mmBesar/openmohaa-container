# syntax=docker/dockerfile:1.4
ARG TARGETPLATFORM=linux/amd64
FROM --platform=${TARGETPLATFORM} debian:bookworm AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git cmake ninja-build clang flex bison \
    zlib1g-dev libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

ENV CC=clang
ENV CXX=clang++

WORKDIR /tmp/openmohaa
RUN git clone --depth 1 --branch main https://github.com/openmoh/openmohaa.git src

WORKDIR /tmp/openmohaa/build
RUN cmake -G Ninja \
      -DBUILD_NO_CLIENT=1 \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DTARGET_LOCAL_SYSTEM=1 \
      -DCMAKE_INSTALL_PREFIX=/usr/local/games/openmohaa \
      ../src && \
    cmake --build . --target install

# ---- Runtime container ----
FROM --platform=${TARGETPLATFORM} debian:bookworm AS final

ENV DEBIAN_FRONTEND=noninteractive
ENV PUID=1000
ENV PGID=1000

RUN apt-get update && apt-get install -y --no-install-recommends \
    socat libcurl4-openssl-dev ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/games/openmohaa /usr/local/games/openmohaa

VOLUME ["/usr/local/share/mohaa"]

# Health check script
RUN echo '#!/bin/bash\n\
header=$'\''\xff\xff\xff\xff\x01disconnect'\''\n\
message=$'\''none'\''\n\
query_port=${GAME_PORT:-12203}\n\
data=""\n\
while [ -z "$data" ]; do\n\
  data=$(echo "$message" | socat - UDP:0.0.0.0:$query_port 2>/dev/null)\n\
  ret=$?\n\
  if [ $ret != 0 ]; then\n\
    echo "Fail (socat returned $ret)"\n\
    exit 1\n\
  fi\n\
  if [ -n "$data" ]; then break; fi\n\
done\n\
if [ "$data" != "$header" ]; then\n\
  echo "Fail (not matching header)"\n\
  exit 1\n\
fi\n\
exit 0' > /usr/local/bin/health_check.sh && chmod +x /usr/local/bin/health_check.sh

# Entrypoint script with UID:GID logic
RUN echo '#!/bin/bash\n\
set -e\n\
PUID=${PUID:-1000}\n\
PGID=${PGID:-1000}\n\
if ! getent group ${PGID} >/dev/null; then groupadd -g ${PGID} mohaa; fi\n\
if ! getent passwd ${PUID} >/dev/null; then useradd -u ${PUID} -g ${PGID} -m mohaa; fi\n\
chown -R ${PUID}:${PGID} /usr/local/share/mohaa || true\n\
exec su-exec ${PUID}:${PGID} /usr/local/games/openmohaa/lib/openmohaa/omohaaded +set fs_homepath home +set dedicated 2 +set net_port ${GAME_PORT:-12203} +set net_gamespy_port ${GAMESPY_PORT:-12300} "$@"' \
> /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

# Install su-exec
RUN apt-get update && apt-get install -y --no-install-recommends su-exec && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local/share/mohaa
EXPOSE 12203/udp 12300/udp

HEALTHCHECK --interval=15s --timeout=20s --start-period=10s --retries=3 \
  CMD ["bash", "/usr/local/bin/health_check.sh"]

ENTRYPOINT ["bash", "/usr/local/bin/entrypoint.sh"]
