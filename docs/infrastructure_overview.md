# Infrastructure Overview

This document provides a comprehensive overview of the managed NixOS infrastructure, including hosts, roles, networking, and shared configurations.

## 🖥️ Hosts & Roles

| Hostname | Type | Role | Hardware / OS Notes |
| :--- | :--- | :--- | :--- |
| `amateur` | Local Desktop | Core Deployment & Dev | AMD CPU/GPU, Gaming, Streaming, AI, Libvirt |
| `trolllollo` | Notebook | Mobile Workstation | ThinkPad T470s, Remote Play enabled |
| `bettenlager` | Notebook | Mobile Workstation | ThinkPad X230, Remote Play enabled |
| `tentacle` | VPS (Hetzner) | VPN Gateway | Critical Infrastructure, WireGuard Hub (`ttvpn`) |
| `server` | Server | Network Uplink | Connectivity provider for the stack |

## 🌐 Network Architecture (ttvpn)

The infrastructure uses a private WireGuard network managed by `tentacle`.

- **IPv4 Range:** `10.111.101.0/24`
- **IPv6 Range:** `fd72:db04:ef1a::/48`
- **Hub:** `tentacle` (Listening on port `52342`)
- **Peers:**
    - `GL-AX1800`
    - `WSL2-spare`
    - `trolllollo`
    - `iPhone12`

## 🎨 Shared Configurations

### User Profiles (`anderer`)
Workstations share common profiles and aesthetic settings via Home Manager and Stylix.

- **Stylix Theme:** Base16 `chalk.yaml` (Dark Mode)
- **Fonts:**
    - Monospace: `CommitMono`
    - Sans-Serif: `Inter`
    - Serif: `Noto Serif`
- **Terminal:** `tmux` (configured), `btop`/`bottom` (monitoring), `eza` (ls replacement).

### System-Wide Standards
- **Secrets Management:** Managed via `sops-nix`.
- **Package Management:** Nix Flakes.
- **Development Tools:** `sops`, `ssh-to-age`, `nixos-anywhere`.
