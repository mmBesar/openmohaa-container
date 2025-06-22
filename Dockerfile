# syntax=docker/dockerfile:1.7

ARG TARGETPLATFORM=linux/amd64
FROM --platform=${TARGETPLATFORM} debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV CC=clang
ENV CXX=clang++

# Install build dependencies in a single layer
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    cmake \
    ninja-build \
    clang \
    flex \
    bison \
    zlib1g-dev \
    libcurl4-openssl-dev

WORKDIR /tmp/openmohaa

# Clone source code
RUN --mount=type=cache,target=/root/.cache/git \
    git clone --depth 1 --branch main https://github.com/openmoh/openmohaa.git src

# Build the application
WORKDIR /tmp/openmohaa/build
RUN cmake -G Ninja \
    -DBUILD_NO_CLIENT=1 \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DTARGET_LOCAL_SYSTEM=1 \
    -DCMAKE_INSTALL_PREFIX=/usr/local/games/openmohaa \
    ../src && \
    cmake --build . --target install --parallel $(nproc)

# --- Final runtime image ---
FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="OpenMoHAA Server"
LABEL org.opencontainers.image.description="Medal of Honor: Allied Assault dedicated server"
LABEL org.opencontainers.image.source="https://github.com/openmoh/openmohaa"
LABEL org.opencontainers.image.licenses="GPL-2.0"

ENV DEBIAN_FRONTEND=noninteractive
ENV GAME_PORT=12203
ENV GAMESPY_PORT=12300
ENV MOHAA_USER=openmohaa
ENV MOHAA_UID=1000
ENV MOHAA_GID=1000

# Install runtime dependencies and create user
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    socat \
    libcurl4-openssl-dev \
    util-linux \
    tini \
    ca-certificates && \
    groupadd -g ${MOHAA_GID} ${MOHAA_USER} && \
    useradd -u ${MOHAA_UID} -g ${MOHAA_GID} -m -s /bin/bash ${MOHAA_USER}

# Copy built application from builder stage
COPY --from=builder --chown=${MOHAA_USER}:${MOHAA_USER} /usr/local/games/openmohaa /usr/local/games/openmohaa

# Create entrypoint script with better error handling
COPY <<'EOF' /usr/local/bin/entrypoint.sh
#!/bin/bash
set -euo pipefail

# Ensure we have proper permissions
if [[ $EUID -eq 0 ]]; then
    echo "Starting as root, switching to ${MOHAA_USER}..."
    exec gosu ${MOHAA_USER} "$0" "$@"
fi

# Set default values
GAME_PORT=${GAME_PORT:-12203}
GAMESPY_PORT=${GAMESPY_PORT:-12300}

echo "Starting OpenMoHAA server..."
echo "Game port: ${GAME_PORT}"
echo "GameSpy port: ${GAMESPY_PORT}"

# Start the server
exec /usr/local/games/openmohaa/lib/openmohaa/omohaaded \
    +set fs_homepath home \
    +set dedicated 2 \
    +set net_port "${GAME_PORT}" \
    +set net_gamespy_port "${GAMESPY_PORT}" \
    "$@"
EOF

# Create health check script with better error handling
COPY <<'EOF' /usr/local/bin/health_check.sh
#!/bin/bash
set -euo pipefail

GAME_PORT=${GAME_PORT:-12203}
TIMEOUT=${HEALTH_TIMEOUT:-5}

# Simple UDP port check
if timeout "${TIMEOUT}" bash -c "</dev/udp/127.0.0.1/${GAME_PORT}" 2>/dev/null; then
    exit 0
else
    echo "Health check failed: port ${GAME_PORT} not responding"
    exit 1
fi
EOF

# Install gosu for proper user switching
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends gosu && \
    gosu nobody true

# Make scripts executable
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/health_check.sh

# Create necessary directories
RUN mkdir -p /usr/local/share/mohaa && \
    chown -R ${MOHAA_USER}:${MOHAA_USER} /usr/local/share/mohaa

# Set up volumes and working directory
VOLUME ["/usr/local/share/mohaa"]
WORKDIR /usr/local/share/mohaa

# Expose ports
EXPOSE ${GAME_PORT}/udp ${GAMESPY_PORT}/udp

# Health check with configurable timeout
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD ["/usr/local/bin/health_check.sh"]

# Use tini as init system and switch to non-root user
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD []
