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

| Service | Image | Port | Description |
|---|---|---|---|
| mosquitto | eclipse-mosquitto:2.0 | 1883, 9001 | MQTT broker (MQTT + WebSockets) |
| mosquitto-ui | smeagolworms4/mqtt-explorer | 4000 | MQTT Explorer web UI |
| gv-web | gv-web-gv-web | 3000 | Habits tracker web app |
| habits_api | gv-api-api | 8080 | Habits tracker API |
| habits_db | postgres:15-alpine | 5432 | PostgreSQL database |

## Mosquitto

Config at `~/docker/mqtt-broker/mosquitto/config/mosquitto.conf`.
