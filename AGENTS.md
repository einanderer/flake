# 🤖 Agent Instructions

## 🛠️ Core Commands

### NixOS Management
- **Apply configuration locally:** `nh os switch .`
- **Rebuild NixOS (alternative):** `nixos-rebuild switch`
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

## 📝 Development Workflow
- **Linting/Formatting:** Uses `treefmt.nix` and `git-hooks.nix`.
- **Dev Shell:** Use `nix develop` to enter a shell with `sops`, `ssh-to-age`, and `nixos-anywhere`.
