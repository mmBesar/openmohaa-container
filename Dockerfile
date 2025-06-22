# Multi-stage build for OpenMoHAA dedicated server
# Stage 1: Build OpenMoHAA from source
FROM debian:bookworm-slim as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libgl1-mesa-dev \
    libopenal-dev \
    libsdl2-dev \
    libcurl4-openssl-dev \
    libjpeg-dev \
    libpng-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone and build OpenMoHAA
WORKDIR /build
ARG OPENMOHAA_VERSION=master
RUN git clone --depth 1 --branch ${OPENMOHAA_VERSION} https://github.com/openmoh/openmohaa.git

WORKDIR /build/openmohaa
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release -DFEATURE_SERVER_ONLY=ON
RUN cmake --build build --config Release --parallel $(nproc)

# Stage 2: Runtime image
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libopenal1 \
    libsdl2-2.0-0 \
    libcurl4 \
    libjpeg62-turbo \
    libpng16-16 \
    zlib1g \
    socat \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /usr/local/games/openmohaa/lib/openmohaa \
    && mkdir -p /usr/local/share/mohaa

# Copy the built server binary from builder stage
COPY --from=builder /build/openmohaa/build/omohaaded /usr/local/games/openmohaa/lib/openmohaa/

# Make binary executable
RUN chmod +x /usr/local/games/openmohaa/lib/openmohaa/omohaaded

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create user for running the server
RUN groupadd -g 1000 mohaa && useradd -u 1000 -g mohaa -s /bin/bash mohaa

# Set ownership
RUN chown -R mohaa:mohaa /usr/local/games/openmohaa /usr/local/share/mohaa

# Expose ports
EXPOSE 12203/udp 12300/udp

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD echo "status" | socat - UDP:localhost:12203,connect-timeout=3 || exit 1

# Set working directory
WORKDIR /usr/local/share/mohaa

# Default environment variables
ENV GAME_PORT=12203
ENV GAMESPY_PORT=12300

# Use the mohaa user by default
USER mohaa

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["+set", "com_target_game", "0", "+set", "sv_maxclients", "16", "+exec", "server.cfg"]
