# Secure Boot Module

This folder now keeps Secure Boot logic split into small modules so the current
Limine-based host can stay stable while Secure Boot work remains explicit.

## Layout

- `default.nix`: imports the Secure Boot submodules
- `options.nix`: shared `modules.secureBoot.*` options
- `sbctl.nix`: manual-key workflow for the current Limine setup
- `lanzaboote.nix`: guarded Lanzaboote flow for a future systemd-boot migration

## Modes

### `mode = "sbctl"`

Use this with the current bootloader. It installs `sbctl` and validates that
key material exists under `modules.secureBoot.pkiBundle`.

Recommended host snippet:

```nix
modules.secureBoot = {
  enable = true;
  mode = "sbctl";
};
```

Key setup:

```bash
sudo sbctl create-keys
sudo mkdir -p /etc/secureboot
sudo cp -r /usr/share/secureboot/keys /etc/secureboot/
sudo sbctl enroll-keys --microsoft
```

### `mode = "lanzaboote"`

Use this only after:

1. adding a `lanzaboote` flake input,
2. importing `lanzaboote.nixosModules.lanzaboote`,
3. moving off the current Limine boot path.

The module asserts if Lanzaboote is requested without those prerequisites.

## Why it stays disabled by default

This host currently boots with Limine and dual-boots Windows from another NVMe.
Changing Secure Boot behavior without an intentional bootloader migration would
be risky, so the module is implemented and validated structurally but not forced
on automatically.
