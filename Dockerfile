# syntax=docker/dockerfile:1.4
ARG TARGETPLATFORM=linux/amd64
FROM --platform=${TARGETPLATFORM} debian:bullseye-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
  build-essential cmake ninja-build flex bison git \
  libsdl2-dev libopenal-dev libcurl4-openssl-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy only the project code (adjust if CMakeLists.txt is elsewhere)
COPY . .

RUN mkdir out && cd out && \
  cmake ../code \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_NO_CLIENT=1 \
    -DCMAKE_INSTALL_PREFIX=/opt/openmohaa && \
  cmake --build . --target install

# Final runtime image
ARG TARGETPLATFORM=linux/amd64
FROM --platform=${TARGETPLATFORM} debian:bullseye-slim

RUN apt-get update && apt-get install -y \
  libsdl2-2.0-0 libopenal1 curl \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/openmohaa /opt/openmohaa

WORKDIR /opt/openmohaa

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--help"]
