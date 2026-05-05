# Secure Boot Module

This module provides declarative Secure Boot support using **Lanzaboote**, a Secure Boot-capable bootloader that automatically signs the kernel, initrd, and boot files on each NixOS rebuild.

## Features

- Automatic kernel and boot file signing on rebuild
- Integration with `sbctl` for key management
- Microsoft-compatible key enrollment for dual-boot scenarios
- Validation checks to ensure keys are present before boot

## Prerequisites

1. **UEFI firmware** with Secure Boot support
2. **Disabled Secure Boot** in BIOS/UEFI (enable after key enrollment)
3. **systemd-boot** as the current bootloader (Lanzaboote replaces it)

## Setup Instructions

### 1. Generate Secure Boot Keys

```bash
sudo sbctl create-keys
```

This creates keys in `/usr/share/secureboot/keys/`:
- `PK` (Platform Key)
- `KEK` (Key Exchange Key)
- `db` (Signature Database)

### 2. Copy Keys to System Location

```bash
sudo mkdir -p /etc/secureboot
sudo cp -r /usr/share/secureboot/keys /etc/secureboot/
```

### 3. Enable the Module

In your `hosts/<hostname>/default.nix`:

```nix
modules.secureBoot.enable = true;
```

### 4. Rebuild and Enroll Keys

```bash
sudo nixos-rebuild switch --flake .#<hostname>
sudo sbctl enroll-keys --microsoft
```

The `--microsoft` flag includes Microsoft's keys, allowing Windows and other signed bootloaders to work alongside NixOS.

### 5. Enable Secure Boot in BIOS

Reboot, enter BIOS/UEFI settings, and enable Secure Boot.

## Verification

Check Secure Boot status:

```bash
sudo sbctl status
```

Expected output:
```
Installed:      ✓ sbctl is installed
Setup Mode:     ✓ Disabled
Secure Boot:    ✓ Enabled
```

## Troubleshooting

### Boot Fails After Enabling Secure Boot

1. Disable Secure Boot in BIOS
2. Boot into NixOS
3. Check signing status: `sudo sbctl verify`
4. Re-sign if needed: `sudo sbctl sign-all`
5. Re-enable Secure Boot

### Keys Not Found Warning

If you see "Secure Boot keys not found" during activation:

```bash
sudo sbctl create-keys
sudo mkdir -p /etc/secureboot
sudo cp -r /usr/share/secureboot/keys /etc/secureboot/
sudo nixos-rebuild switch --flake .#<hostname>
```

## References

- [Lanzaboote Documentation](https://github.com/nix-community/lanzaboote)
- [sbctl GitHub](https://github.com/Foxboron/sbctl)
- [NixOS Secure Boot Wiki](https://nixos.wiki/wiki/Secure_Boot)
