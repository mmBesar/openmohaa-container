# OpenMoHAA Dedicated Server (Docker)

> **⚠️ Project status: Not production ready. Expect bugs and instability.**

This Docker setup builds a lightweight, multi-architecture container image for the [OpenMoHAA](https://github.com/openmoh/openmohaa) dedicated server. It's designed for Raspberry Pi 4, ARMv7, ARM64, and x86_64 platforms.

---

## Features

- Minimal runtime image using Debian 11 slim
- Fast native builds with full source control
- GitHub Actions for CI and multi-arch build/publish

---

## Quick Start

```sh
docker-compose -f docker-compose.example.yml up -d
```

Customize `./config/server.cfg` and put your `main/` assets into `./assets/`.

---

## Build Locally

```sh
docker buildx build \
  --platform linux/amd64,linux/arm64,linux/arm/v7 \
  --push \
  -t ghcr.io/YOUR_USERNAME/openmohaa:latest .
```

Replace `YOUR_USERNAME` with your GitHub username.

---

## License

GPL-2.0. Original Medal of Honor assets not included.

---

## Status

> This image is under active development. Use with caution.
