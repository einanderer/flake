---
name: sops-secrets
description: Manage SOPS-encrypted secrets in the flake (secrets/, .sops.yaml) — adding machines, rotating keys, editing and decrypting secrets. Use whenever creating, reading, or rotating secrets, or touching .sops.yaml.
---

# sops-secrets

Secrets in this flake are encrypted with SOPS and live in `secrets/`. The keyring config is `.sops.yaml`. Always work inside the dev shell (`nix develop`); never use ad-hoc installs.

## Add a new machine

1. Get its public key:
   ```bash
   ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
   ```
2. Add the key to `.sops.yaml` (recipients section) and commit.
3. Rotate existing encrypted secrets so the new key can decrypt them:
   ```bash
   sops updatekeys secrets.yaml
   ```

## Rotate keys for an existing machine

```bash
sops updatekeys secrets.yaml
```
After rotation all encrypted values are re-encrypted to the current key set.

## Read an encrypted secret

```bash
sops decrypt <file>
```
- For a single secret: `sops decrypt <file> --show <path.to.value>`
- **Never pipe decrypted secrets into a second process or a file.** `sops decrypt file > /tmp/x` writes plaintext to disk. Use `sops edit` for changes.

## Edit a secret (preferred way to change values)

```bash
sops edit <file>
```
Opens the decrypted file in `$EDITOR`. On save, SOPS re-encrypts. **Do not** do `sops edit` by hand and `sops encrypt` yourself — `sops edit` is the safe, atomic path.

## Rules

1. **Never commit decrypted secrets.** `sops edit` keeps the file encrypted on disk; a plain `cat secrets/file` shows ciphertext only when the file is encrypted.
2. **Never `git push` a temporarily decrypted file** — SOPS decrypts to a temp file, but if you copy plaintext into the repo it goes up.
3. After any secret change, the dependent machine(s) must be rebuilt. `secrets/` changes usually require a rebuild of the hosts that consume them.
4. If `sops edit` fails because the editor is not found, set `EDITOR` or `VISUAL` first (the dev shell has one).
