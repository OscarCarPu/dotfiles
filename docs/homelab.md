# Homelab

> Temporal documentation of my homelab setup. Subject to change as services evolve.

## Hardware

- **Machine:** Lenovo ThinkCentre M920Q
- **CPU:** Intel Core i5-8500T @ 2.10GHz (6 cores, no HT)
- **RAM:** 16GB DDR4
- **Storage:** 233GB NVMe SSD
- **Network:** Gigabit Ethernet (eno1)

## OS

- **Distro:** Debian 12 (Bookworm)
- **Kernel:** 6.1.0-42-amd64
- **Hostname:** homelabocp
- **IP:** 192.168.1.135 (DHCP)

## Docker Services

All services run as Docker containers under `~/docker/`.

| Service | Image | Port | Description | Exported to |
|---|---|---|---|---|
| mosquitto | eclipse-mosquitto:2.0 | 1883, 9001 | MQTT broker (MQTT + WebSockets) | |
| mosquitto-ui | smeagolworms4/mqtt-explorer | 4000 | MQTT Explorer web UI | |
| gv-web | gv-web-gv-web | 3000 | Habits tracker web app | gv.lab-ocp.com |
| gv_api | gv-api-api | 8080 | Habits tracker API | gv-api.lab-ocp.com |
| gv_db | postgres:15-alpine | 5432 | PostgreSQL database | |
| gitea | gitea/gitea:1.25.4 | 3001 | Gitea web app | git.lab-ocp.com |

## Mosquitto

Config at `~/docker/mqtt-broker/mosquitto/config/mosquitto.conf`.
