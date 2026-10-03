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

## 🧠 Intelligence & Preferences

### Path Awareness
- Most active development and project-specific configurations are located within `~/Projekte/`.
- Always ensure tool configurations (like Taskwarrior's `.taskrc`) are correctly placed within their respective project contexts to avoid polluting the home directory.

### Terminal & Tooling
- **Terminal-Centric:** The user environment heavily utilizes terminal multiplexers (e.g., Zellij) and CLI-first tools. 
- **Existing Utilities:** Always check `~/.local/bin/` for existing scripts or custom utilities before implementing new ones to avoid duplication.

### LSP Debugging Protocol
- When LSP issues are reported, the standard procedure is to use the automated diagnostic script: `./scripts/test-lsp.sh`.
- Do not assume LSP availability; verify via headless Neovim commands (`:LspInfo`, `:checkhealth lsp`) if issues persist.

### Task Management
- Use the Taskwarrior MCP integration to track long-term tasks and development workflows.
- Register new diagnostic or testing workflows as persistent tasks.

### Path Awareness
- Most active development and project-specific configurations are located within `~/Projekte/`.
- Always ensure tool configurations (like Taskwarrior's `.taskrc`) are correctly placed within their respective project contexts to avoid polluting the home directory.

### Terminal & Tooling
- **Terminal-Centric:** The user environment heavily utilizes terminal multiplexers (e.g., Zellij) and CLI-first tools. 
- **Existing Utilities:** Always check `~/.local/bin/` for existing scripts or custom utilities before implementing new ones to avoid duplication.

### LSP Debugging Protocol
- When LSP issues are reported, the standard procedure is to use the automated diagnostic script: `./scripts/test-lsp.sh`.
- Do not assume LSP availability; verify via headless Neovim commands (`:LspInfo`, `:checkhealth lsp`) if issues persist.

### Task Management
- Use the Taskwarrior MCP integration to track long-term tasks and development workflows.
- Register new diagnostic or testing workflows as persistent tasks.
