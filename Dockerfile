# syntax=docker/dockerfile:1.4
ARG TARGETPLATFORM=linux/amd64
FROM --platform=${TARGETPLATFORM} debian:bookworm AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    git cmake ninja-build clang flex bison \
    zlib1g-dev libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

ENV CC=clang
ENV CXX=clang++

WORKDIR /tmp/openmohaa

# Clone official repo (latest main branch only)
RUN git clone --depth 1 --branch main https://github.com/openmoh/openmohaa.git src

# Build
WORKDIR /tmp/openmohaa/build
RUN cmake -G Ninja \
      -DBUILD_NO_CLIENT=1 \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DTARGET_LOCAL_SYSTEM=1 \
      -DCMAKE_INSTALL_PREFIX=/usr/local/games/openmohaa \
      ../src && \
    cmake --build . --target install

# -------------------------------------
# Final runtime image (base variant)
# -------------------------------------
FROM --platform=${TARGETPLATFORM} debian:bookworm AS final

RUN apt-get update && apt-get install -y --no-install-recommends \
    socat libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/games/openmohaa /usr/local/games/openmohaa

VOLUME ["/usr/local/share/mohaa"]

# Inline health_check.sh
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

# Inline entrypoint.sh
RUN echo '#!/bin/bash\n\
/usr/local/games/openmohaa/lib/openmohaa/omohaaded +set fs_homepath home +set dedicated 2 +set net_port ${GAME_PORT:-12203} +set net_gamespy_port ${GAMESPY_PORT:-12300} "$@"' \
> /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

# Secure runtime
RUN useradd -m openmohaa
USER openmohaa

WORKDIR /usr/local/share/mohaa
EXPOSE 12203/udp 12300/udp

HEALTHCHECK --interval=15s --timeout=20s --start-period=10s --retries=3 \
  CMD ["bash", "/usr/local/bin/health_check.sh"]

ENTRYPOINT ["bash", "/usr/local/bin/entrypoint.sh"]
