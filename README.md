# OpenMoHAA Dedicated Server (Containerized)

> **⚠️ Disclaimer:**
> This project is **not affiliated with EA** or any official MoHAA project.
> This repository is **solely for personal use**.
> It is **not** affiliated with, endorsed by, or connected in any way to the [OpenMoHAA](https://github.com/openmoh/openmohaa) project.
> Use at your own risk. No warranties are provided.

---

## 📌 Status

> **⚠️ Project status: Not production-ready. Expect bugs and active development.**

This container runs the [OpenMoHAA](https://github.com/openmoh/openmohaa) dedicated server, automatically built and published whenever a new upstream release is tagged. Supports multi-arch (AMD64/ARM64/RISC-V) and works well on Raspberry Pi 4/5. Includes support for Docker/Podman, custom game assets, bots, and RCON-based control.

---

## ✅ Features

- Multi-architecture builds (amd64, arm64, riscv64)
- Minimal Debian Trixie (13) runtime
- Automatically rebuilt on every new upstream release
- Works with Docker & Podman
- Auto health checks via UDP probe
- Game assets mounted via volume
- UID/GID support for permission matching

---

## 🏷️ Image Tags

Images are published to the GitHub Container Registry (GHCR):

| Tag | Description |
|---|---|
| `latest` | Multi-arch manifest, latest upstream release |
| `vX.Y.Z` | Multi-arch manifest, specific upstream version |
| `latest-amd64` | Single-arch, amd64 |
| `latest-arm64` | Single-arch, arm64 |
| `latest-riscv64` | Single-arch, riscv64 |
| `vX.Y.Z-amd64` | Single-arch, specific version |

For most users, just use `latest` — Docker will automatically pull the correct arch for your machine.

```
ghcr.io/mmbesar/openmohaa-container:latest
```

---

## 📦 Folder Structure & Mount Points

```bash
openmohaa/
└── mohaa
    ├── home
    │   └── main
    │       ├── configs
    │       │   ├── omconfig.cfg
    │       │   └── unnamedsoldier.cfg
    │       ├── OpenMoHAA_server.pid
    │       ├── server.cfg
    │       └── settings
    ├── main
    │   ├── Pak0.pk3
    │   ├── Pak1.pk3
    │   ├── Pak2.pk3
    │   ├── Pak3.pk3
    │   ├── Pak4.pk3
    │   ├── Pak5.pk3
    │   ├── Pak6EnUk.pk3
    │   └── pak7.pk3
    ├── mainta
    │   ├── pak1.pk3
    │   ├── pak2.pk3
    │   ├── pak3.pk3
    │   ├── pak4.pk3
    │   └── pak5.pk3
    ├── maintt
    │   ├── pak1.pk3
    │   ├── pak2.pk3
    │   ├── pak3.pk3
    │   └── pak4.pk3
    └── mods
        └── my-mod
```

---

## 🧩 Docker Compose Example

```yaml
services:
  openmohaa:
    image: ghcr.io/mmbesar/openmohaa-container:latest
    container_name: openmohaa
    network_mode: "host"
    restart: unless-stopped
    user: "${PUID}:${PGID}"
    environment:
      GAME_PORT: 12203
      GAMESPY_PORT: 12300
    volumes:
      - ${CONTAINER_DIR}/openmohaa/mohaa:/usr/local/share/mohaa
    command:
      [
        "+set", "com_target_game", "0",
        "+set", "sv_maxclients", "16",
        "+exec", "server.cfg"
      ]
```

---

## 🚪 Ports

| Port | Protocol | Purpose |
|---|---|---|
| `12203` | UDP | Game traffic |
| `12300` | UDP | GameSpy listing |

> LAN-only use? You may omit port 12300 and set `set sv_gamespy 0` in `server.cfg`

---

## 🩺 Health Check (Built-in)

Container includes a health check that:

- Sends a dummy UDP packet
- Waits for disconnect response

Implemented via `HEALTHCHECK` and `socat`. No impact on logs or performance.

---

## 🧠 Server Configuration

Use `server.cfg` to define:

```cfg
set sv_hostname "My OpenMoHAA Server"
set g_gametype 1          // FFA, TDM, OBJ, etc
set sv_maxclients 16      // Must also be passed as a startup arg
set bot_enable 1
set bot_minplayers 4
set bot_maxplayers 12
set bot_difficulty 2
sv_maplist "obj/obj_team1 obj/obj_team2"
map "obj/obj_team1"
```

> ✅ `sv_maxclients` must be passed as a startup arg (in the `command:` block), not only in `server.cfg`

> ✅ As of upstream v0.82.0, the `mp-navigation.pk3` file is no longer needed — bots use the built-in Recast Navigation system automatically.

---

## 🎮 RCON / Remote Control

To control the server at runtime:

- Enable RCON with `set rconpassword "yourpass"` in `server.cfg`
- Connect via in-game console or tools like `rcon` / `qstat`
- Issue commands like `map`, `g_gametype`, `status`, etc.

---

## 🐛 Known Issues

- `server.cfg` must be placed directly under `main/`, not in subfolders.
- `omconfig.cfg` is generated after first run; live settings may persist there.

---

## 🔄 Automatic Updates

This repo syncs with the upstream [OpenMoHAA](https://github.com/openmoh/openmohaa) repository daily. When a new upstream release tag is detected, a new image is automatically built and published for all three architectures. No manual intervention needed.

---

## 🔧 Building Locally

```bash
# Clone both branches
git clone --branch main https://github.com/mmBesar/openmohaa-container.git
git clone --branch upstream https://github.com/mmBesar/openmohaa-container.git upstream-src

# Build
docker buildx build \
  --platform linux/amd64,linux/arm64,linux/riscv64 \
  --context upstream-src \
  --file openmohaa-container/Dockerfile \
  --push \
  -t ghcr.io/YOUR_USERNAME/openmohaa-container:latest .
```

---

## 📝 License

GPL-2.0. Requires original Medal of Honor: Allied Assault game assets.
