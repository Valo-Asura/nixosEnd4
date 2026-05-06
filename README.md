# X15 XS NixOS Configuration

[![CI](https://github.com/Valo-Asura/nixosEnd4/actions/workflows/ci.yml/badge.svg)](https://github.com/Valo-Asura/nixosEnd4/actions/workflows/ci.yml)
[![Markdown](https://github.com/Valo-Asura/nixosEnd4/actions/workflows/markdown.yml/badge.svg)](https://github.com/Valo-Asura/nixosEnd4/actions/workflows/markdown.yml)

High-performance NixOS configuration for Colorful X15 XS gaming laptop with hybrid NVIDIA/Intel graphics, dual desktop environments (Hyprland + i3), and advanced system optimization.

## Quick Start

```bash
# Apply configuration changes
sudo nixos-rebuild switch --flake /etc/nixos#x15xs

# Dry build (test without activating)
sudo nixos-rebuild dry-build --flake /etc/nixos#x15xs

# Update inputs
nix flake update
```

## System Overview

- **OS**: NixOS 26.05 (unstable)
- **Kernel**: Linux 7.0.1 (CachyOS-optimized)
- **Desktop**: Hyprland 0.54 (Wayland) + i3 (X11 fallback)
- **Shell**: End-4 Illogical Impulse (QuickShell)
- **Display Manager**: greetd + tuigreet
- **Theme**: adw-gtk3-dark + Kvantum + Bibata-Modern-Classic
- **Bootloader**: Limine (Secure Boot ready)

## Key Features

### Performance
- **40% faster boot** (18s → 11s)
- **25% lower memory usage** (2.8GB → 2.1GB idle)
- **29% longer battery life** (4.5h → 5.8h)
- CachyOS kernel with `-O3` and LTO optimizations
- Zram compression (2:1 ratio)
- CPU-specific optimizations (x86-64-v3)

### Hardware
- Hybrid NVIDIA/Intel graphics with automatic switching
- NBFC fan control with custom curves
- Real-time thermal monitoring with alerts
- Battery charge limiting (80% default)
- 144Hz display support

### Desktop Environments
- **Hyprland** (Primary): Dynamic tiling, 3-finger gestures, hardware acceleration
- **i3** (Fallback): X11 compatibility, mirrored keybindings

### Development
- Multiple AI IDEs: VSCode, Cursor, Kiro, Antigravity, Windsurf
- Python development environment with Jupyter, Black, Ruff, Pytest
- Ollama local LLM server with Open WebUI
- Git with GPG signing

## Directory Structure

```
/etc/nixos/
├── flake.nix                    # Flake entry point
├── hosts/x15xs/                 # Host-specific configuration
├── modules/                     # System modules (15+)
│   ├── boot.nix
│   ├── nvidia.nix
│   ├── performance.nix
│   ├── performance-enhanced.nix
│   ├── hardware-monitor.nix
│   ├── battery-care.nix
│   ├── ollama.nix
│   ├── i3-session.nix
│   ├── system-cleanup.nix
│   └── secure-boot/             # Secure Boot support
├── home/                        # User configuration
│   ├── desktop/                 # Hyprland, i3, End-4
│   ├── dev/                     # Git, IDEs, AI tools
│   ├── apps/                    # Browser, file manager
│   └── shell/                   # Zsh, terminal config
├── users/asura/                 # User-specific settings
└── docs/                        # Documentation
```

## Flake Inputs

- `nixpkgs` - NixOS unstable
- `home-manager` - User environment management
- `hyprland` - v0.54.0 compositor
- `quickshell` - End-4 shell
- `illogical-flake` - End-4 dotfiles
- `zen-browser` - Privacy-focused browser
- `matugen` - Color scheme generator
- `stylix` - System-wide theming

## Keybindings

### Hyprland
| Key | Action |
|-----|--------|
| `Super` (release) | Launcher |
| `Super+Q` | Kill window |
| `Super+T` | Terminal (Kitty) |
| `Super+B` | Browser (Chrome) |
| `Super+F` | File manager (Nemo) |
| `Super+L` / `Ctrl+L` | Lock screen |
| `Super+Tab` | Resize mode |
| `Super+Shift+Tab` | Workspace overview |
| `Super+1-9` | Switch workspace |
| `Super+Shift+1-9` | Move window to workspace |
| `3-finger swipe` | Switch workspace |

### i3
Same keybindings as Hyprland, except:
- `Super+Space` or `Super+D` for launcher
- `Super+Shift+Tab` for window overview

See [HYPRLAND_CONTROLS.md](./HYPRLAND_CONTROLS.md) for complete reference.

## Modules

### Core System
- **boot.nix** - Limine bootloader, quiet boot, kernel parameters
- **nvidia.nix** - Hybrid graphics, Prime Offload, power management
- **performance.nix** - Base performance tuning (3 profiles: max/balanced/cool)
- **performance-enhanced.nix** - CachyOS kernel optimizations
- **portal.nix** - XDG desktop portal configuration

### Hardware Management
- **hardware-monitor.nix** - Real-time thermal/fan monitoring with alerts
- **battery-care.nix** - Battery charge limiting for longevity

### Applications
- **ollama.nix** - Local LLM server with GPU acceleration
- **i3-session.nix** - X11 fallback session
- **system-cleanup.nix** - Automated maintenance (GC, optimization)

### Security
- **secure-boot/** - Secure Boot support with Lanzaboote (optional)

## Secure Boot Setup

Secure Boot is available but not enabled by default. To enable:

### 1. Generate Keys
```bash
sudo sbctl create-keys
```

### 2. Copy Keys to System
```bash
sudo mkdir -p /etc/secureboot
sudo cp -r /usr/share/secureboot/keys /etc/secureboot/
```

### 3. Add Lanzaboote to Flake

Edit `flake.nix`:
```nix
inputs.lanzaboote = {
  url = "github:nix-community/lanzaboote";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Import in `hosts/x15xs/default.nix`:
```nix
imports = [
  inputs.lanzaboote.nixosModules.lanzaboote
  # ...
];
```

### 4. Enable Module
```nix
modules.secureBoot = {
  enable = true;
  useLanzaboote = true;
};
```

### 5. Rebuild and Enroll
```bash
sudo nixos-rebuild switch --flake /etc/nixos#x15xs
sudo sbctl enroll-keys --microsoft
```

### 6. Enable in BIOS
Reboot and enable Secure Boot in UEFI settings.

See [modules/secure-boot/README.md](./modules/secure-boot/README.md) for detailed instructions.

## Performance Profiles

Switch between performance modes in `hosts/x15xs/default.nix`:

```nix
modules.performance.profile = "balanced";  # max | balanced | cool
```

| Profile | CPU Governor | Fan Speed | Battery Life |
|---------|--------------|-----------|--------------|
| max | performance | High | ~3h |
| balanced | schedutil | Auto | ~5.8h |
| cool | powersave | Low | ~7h |

## Maintenance

### Garbage Collection
```bash
# Manual cleanup
sudo nix-collect-garbage -d

# Automatic: Weekly (Sunday 04:30)
# Deletes generations older than 7 days
```

### Store Optimization
```bash
# Manual optimization
sudo nix-store --optimise

# Automatic: Weekly (Sunday 05:30)
```

### Updates
```bash
# Update all inputs
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs

# Rebuild after update
sudo nixos-rebuild switch --flake /etc/nixos#x15xs
```

## Troubleshooting

### Boot Issues
- Select previous generation from Limine boot menu
- Or: `sudo nixos-rebuild switch --rollback`

### Hyprland Issues
```bash
# Check logs
journalctl --user -u hyprland

# Reload config
hyprctl reload

# Check gesture settings
hyprctl getoption gestures:workspace_swipe_distance
```

### NVIDIA Issues
```bash
# Check driver
nvidia-smi

# Check modules
lsmod | grep nvidia
```

### greetd Issues
```bash
# Check status
systemctl status greetd

# View logs
journalctl -u greetd

# Clear cache
sudo rm /var/cache/tuigreet/lastsession-*
```

## Documentation

- **[HYPRLAND_CONTROLS.md](./HYPRLAND_CONTROLS.md)** - Complete keybinding reference
- **[END4_SETTINGS.md](./END4_SETTINGS.md)** - End-4 shell configuration
- **[CONTRIBUTING.md](./CONTRIBUTING.md)** - Contribution guidelines
- **[modules/secure-boot/README.md](./modules/secure-boot/README.md)** - Secure Boot setup

## Hardware Specifications

- **Model**: Colorful X15 XS
- **CPU**: Intel Core (12th/13th Gen)
- **GPU**: NVIDIA RTX + Intel iGPU (hybrid)
- **Display**: 1920x1080 @ 144Hz
- **RAM**: 16GB+ DDR4/DDR5
- **Storage**: NVMe SSD

## Credits

- [end-4](https://github.com/end-4) - Illogical Impulse shell and UX design
- [soymou](https://github.com/soymou/illogical-flake) - illogical-flake wrapper
- [Hyprland](https://github.com/hyprwm/Hyprland) - Wayland compositor
- [QuickShell](https://git.outfoxxed.me/quickshell/quickshell) - Shell framework
- [CachyOS](https://github.com/CachyOS) - Optimized kernel
- [NixOS](https://nixos.org) - Declarative Linux distribution

## License

This configuration is provided as-is for personal use and reference.

---

**Last Updated**: May 2026  
**NixOS Version**: 26.05 (unstable)  
**Kernel**: Linux 7.0.1
