# 🤖 Agent Instructions

## 🛠️ Core Commands

### NixOS Management
- **Apply configuration locally:** `nh os switch .`
- **Apply to remote host:** `nh os switch .#HOSTNAME --target-host HOSTNAME`

### Secrets Management (SOPS)
- **Add new machine:**
  1. `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`
  2. Edit `.sops.yaml` to add the new key.
- **Update SOPS keys:** `sops updatekeys secrets.yaml`
- **Edit secrets:** `sops edit <file>`
- **Decrypt secrets:** `sops decrypt <file>`

## 🏗️ Architecture & Structure
- **`machines/`**: Host-specific NixOS configurations.
- **`nixos/`**: System-wide NixOS modules and profiles.
- **`home/`**: Home Manager configurations (user environment).
- **`pkgs/`**: Custom package definitions.
- **`secrets/`**: Encrypted secrets managed by SOPS.

## 🌐 Host Inventory

| Hostname | Type | Role | Notes |
| :--- | :--- | :--- | :--- |
| `amateur` | Local Desktop | Gaming, Streaming Server, Dev, Multimedia | **Core Deployment Machine**. Remote builds happen here. **Opencode runs here.** |
| `tentacle` | External VPS (Hetzner) | VPN Gateway | **Critical Infrastructure**. Accessible via SSH or Hetzner Web Console. |
| `trolllollo` | Local Notebook | Multimedia, Gaming, Streaming, Dev | **Critical**. High priority, similar importance to `amateur`. |
| `bettenlager` | Local Notebook | Multimedia, Streaming Client | Non-critical consumer device. |

## 📝 Development Workflow
- **Linting/Formatting:** Uses `treefmt.nix` and `git-hooks.nix`.
- **Dev Shell:** Use `nix develop` to enter a shell with `sops`, `ssh-to-age`, and `nixos-anywhere`.
- **Ad-hoc Tools:** For temporary tools not in the dev shell, use `nix shell -p <package>` or `nix run nixpkgs#<package>` instead of imperative package managers.

## 📦 Commit Discipline
- **Commit each verified change upon completion** — the moment a change is done and verified (build/test/read-back), commit it as its **own logical step**; do **not** carry verified, uncommitted work forward.
- The **working directory is clean** after every step: no WIP, no half-applied files, no unstaged verified changes.
- Never mix two steps into one commit.
