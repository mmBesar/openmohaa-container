# OpenMoHAA Dedicated Server (Containerized)

> **⚠️ Disclaimer:**
> This project is **not affiliated with EA** or any official MoHAA project.  
> This repository is **solely for personal use**.  
> They are **not** affiliated with, endorsed by, or connected in any way to the [OpenMoHAA](https://github.com/openmoh/openmohaa) project.  
> Use at your own risk. No warranties are provided.

---

## 📌 Status

> This container setup is under development. Use at your own risk.
> **⚠️ Project status: Not production-ready. Expect bugs and active development.**

This container runs the [OpenMoHAA](https://github.com/openmoh/openmohaa) dedicated server, built for multi-arch (AMD64/ARM64/ARMv7) and optimized for Raspberry Pi 4. Includes support for Docker/Podman, custom game assets, bots, and RCON-based control.

---

## ✅ Features

- Multi-architecture builds (amd64, arm64, arm/v7)
- Minimal Debian runtime (Bookworm)
- Works with Docker & Podman
- Auto health checks via UDP probe
- Game assets mounted via volume
- UID/GID support for permission matching

---

## 📦 Folder Structure & Mount Points

```bash
openmohaa/
└── mohaa
    ├── home
    │   └── main
    │       ├── configs
    │       │   ├── omconfig.cfg
    │       │   └── unnamedsoldier.cfg
    │       ├── mp-navigation-v0.0.1.pk3
    │       ├── OpenMoHAA_server.pid
    │       ├── server.cfg
    │       └── settings
    ├── main
    │   ├── aftermath2.pk3
    │   ├── aftermath.pk3
    │   ├── aftermath_revised.pk3
    │   ├── Pak0.pk3
    │   ├── Pak1.pk3
    │   ├── Pak2.pk3
    │   ├── Pak3.pk3
    │   ├── Pak4.pk3
    │   ├── Pak5.pk3
    │   ├── Pak6EnUk.pk3
    │   ├── pak7.pk3
    │   ├── userMAP-aftermath2.pk3
    │   ├── userMAP-aftermath.pk3
    │   ├── userMAP-aftermath_revised.pk3
    │   ├── userMAP-canal.pk3
    │   ├── userMAP-Kmarzo-St Renan.pk3
    │   ├── userMAP-User-Stlo.pk3
    │   └── userMAP-ZzZ_User_La_patrouille_2all_version.pk3
    ├── mainta
    │   ├── pak1.pk3
    │   ├── pak2.pk3
    │   ├── pak3.pk3
    │   ├── pak4.pk3
    │   └── pak5.pk3
    ├── maintt
    │   ├── pak1.pk3
    │   ├── pak2.pk3
    │   ├── pak3.pk3
    │   └── pak4.pk3
    └── mods
        └── my-mod
```

## 🧩 Docker Compose Example

```yaml
services:
  openmohaa:
    image: ghcr.io/mmbesar/openmohaa-container:latest-arm64
    container_name: openmohaa
    network_mode: "host"
    restart: unless-stopped
    user: "${PUID}:${PGID}"
    ports:
      - "12203:12203/udp" # Game port
      - "12300:12300/udp" # Gamespy port
    volumes:
      - ${CONTAINER_DIR}/openmohaa/mohaa:/usr/local/share/mohaa
    environment:
      GAME_PORT: 12203
      GAMESPY_PORT: 12300
    command:
      [
        # "+set", "fs_homepath", "home",
        "+set", "com_target_game", "0",
        "+set", "sv_maxclients", "16",
        "+exec", "server.cfg"
      ]
```

---

## 🚪 Ports

| Port    | Protocol | Purpose         |
| ------- | -------- | --------------- |
| `12203` | UDP      | Game traffic    |
| `12300` | UDP      | GameSpy listing |

> LAN-only use? You may omit port 12300 and set `set sv_gamespy 0` in `server.cfg`

---

## 🩺 Health Check (Built-in)

Container includes a health check that:

* Sends a dummy UDP packet
* Waits for disconnect response

Implemented via `HEALTHCHECK` and `socat`. No impact on logs or performance.

---

## 🧠 Server Configuration

Use `server.cfg` to define:

```cfg
set sv_hostname "My OpenMoHAA Server"
set g_gametype 1                     // FFA, TDM, OBJ, etc
set sv_maxclients 16                // Set at startup via command args
set bot_enable 1
set bot_minplayers 4
set bot_maxplayers 12
set bot_difficulty 2
sv_maplist "obj/obj_team1 obj/obj_team2"
map "obj/obj_team1"
```

> ✅ Max players (`sv_maxclients`) must be passed as a startup arg, not just in `server.cfg`

---

## 🎮 RCON / Remote Control

To control the server at runtime:

* Enable RCON with `set rconpassword "yourpass"`
* Connect via in-game console or tools like `rcon`/`qstat`
* Issue commands like `map`, `g_gametype`, `status`, etc.

---

## 🐛 Known Issues

* Bots won’t move if nav data is missing from the map.
* server.cfg must be placed under `main/` not in subfolders.
* `omconfig.cfg` is generated after first run; live settings may persist there.

---

## 🔧 Building Locally

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64,linux/arm/v7 \
  --push \
  -t ghcr.io/YOUR_USERNAME/openmohaa-container:latest .
```

---

## 📝 License

GPL-2.0. Requires original Medal of Honor game assets.

