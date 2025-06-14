# syntax=docker/dockerfile:1.4
ARG TARGETPLATFORM=linux/amd64
FROM --platform=${TARGETPLATFORM} debian:bullseye-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake ninja-build flex bison git \
    libsdl2-dev libopenal-dev libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /openmohaa
COPY . .

RUN mkdir build && cd build && \
    cmake .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_NO_CLIENT=1 \
      -DCMAKE_INSTALL_PREFIX=/opt/openmohaa \
    && cmake --build . --target install

FROM --platform=$TARGETPLATFORM debian:bullseye-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libsdl2-2.0-0 libopenal1 curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/openmohaa /opt/openmohaa
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /opt/openmohaa

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--help"]
