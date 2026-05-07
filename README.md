<div align="center">

# 🚀 X15 XS NixOS Configuration

[![GitHub Profile](https://img.shields.io/badge/GitHub-Valo--Asura-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Valo-Asura)
[![NixOS](https://img.shields.io/badge/NixOS-26.05-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](https://nixos.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-0.54-00D9FF?style=for-the-badge&logo=wayland&logoColor=white)](https://hyprland.org)

[![CI](https://github.com/Valo-Asura/nixosEnd4/actions/workflows/ci.yml/badge.svg)](https://github.com/Valo-Asura/nixosEnd4/actions/workflows/ci.yml)
[![Markdown](https://github.com/Valo-Asura/nixosEnd4/actions/workflows/markdown.yml/badge.svg)](https://github.com/Valo-Asura/nixosEnd4/actions/workflows/markdown.yml)

**High-performance NixOS configuration for Colorful X15 XS gaming laptop**  
*Hybrid NVIDIA/Intel graphics • Dual desktop environments (Hyprland + i3) • Advanced system optimization*

[Quick Start](#quick-start) • [Features](#key-features) • [Documentation](#documentation) • [Credits](#credits)

---

</div>

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
- **Kernel**: Linux 7.0.3 via `linuxPackages_latest`
- **Desktop**: Hyprland 0.54 (Wayland) + i3 (X11 fallback)
- **Shell**: QuickShell profiles: End-4 default, ilyamiro optional
- **Display Manager**: greetd + tuigreet
- **Theme**: adw-gtk3-dark + Kvantum + Bibata-Modern-Classic
- **Bootloader**: Limine (Secure Boot ready)

## Key Features

### Performance
- **faster boot** (11s)
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
- **Hyprland** (Primary): Dynamic tiling, 3-finger gestures, profile-switched QuickShell
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
│   ├── desktop/                 # Hyprland, i3, QuickShell, End-4
│   ├── dev/                     # Git, IDEs, AI tools
│   ├── apps/                    # Browser, media, MIME, file manager
│   └── shell/                   # Zsh, terminal, fastfetch config
├── users/asura/                 # User-specific settings
└── docs/                        # Documentation
```

## Flake Inputs

- `nixpkgs` - NixOS unstable
- `home-manager` - User environment management
- `hyprland` - v0.54.0 compositor
- `quickshell` - End-4 shell
- `illogical-flake` - End-4 dotfiles
- `ilyamiro-nixos-configuration` - ilyamiro QuickShell profile only
- `zen-browser` - Privacy-focused browser
- `matugen` - Color scheme generator
- `stylix` - System-wide theming

## Keybindings

### Hyprland
| Key | Action |
|-----|--------|
| `Super+Q` | Kill window |
| `Super+T` | Terminal (Kitty) |
| `Super+Return` | Terminal (Kitty) |
| `Super+B` | Browser (Chrome) |
| `Super+F` | File manager (Nemo) |
| `Super` / `Super+Space` / `Super+D` | Launcher |
| `Super+L` / `Ctrl+L` | Lock screen |
| `Super+Shift+C` / `Super+Alt+C` | Clipboard |
| `Super+Tab` | Resize mode |
| `Super+Shift+Tab` | Workspace overview |
| `Super+1-9` | Switch workspace |
| `Super+Shift+1-9` | Move window to workspace |
| `3-finger horizontal swipe` | Switch workspace, creating the next inactive workspace at the edge |

### i3
Same keybindings as Hyprland, except:
- `Super+Shift+Tab` for window overview

## Modules

### Core System
- **boot.nix** - Limine bootloader and latest packaged kernel selection
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
- **home/apps/media.nix** - Camera, microphone, PipeWire graph, and playback tools
- **home/shell/terminal.nix** - Kitty and Foot theme ownership

### Security
- **secure-boot/** - Secure Boot support with Lanzaboote (optional)

## QuickShell Profiles

End-4 stays the default profile. The ilyamiro repository is pinned as a flake input and only its `config/sessions/hyprland/scripts` QuickShell tree is copied into `~/.config/hypr/scripts`; its NixOS and Hyprland system config are not imported.

```bash
# Show active profile
quickshell-profile

# Switch live profile and restart QuickShell
quickshell-switch end4
quickshell-switch ilyamiro

# Restart whichever profile is active
quickshell-reload
```

Clipboard history is captured by Home Manager user services (`cliphist-text` and `cliphist-image`), so `clipboard` works with either profile.

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

- **README.md** - Central system, controls, performance, and maintenance reference
- **[END4_SETTINGS.md](./END4_SETTINGS.md)** - End-4 shell configuration
- **[docs/X15_UNIFIED_WORKFLOW.md](./docs/X15_UNIFIED_WORKFLOW.md)** - AI workstation workflow and local LLM notes
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

### Desktop Environment & Shell
- **[end-4/illogical-impulse](https://github.com/end-4/illogical-impulse)** - Beautiful, feature-rich shell and UX design
- **[soymou/illogical-flake](https://github.com/soymou/illogical-flake)** - Nix flake wrapper for End-4's dotfiles
- **[ilyamiro/nixos-configuration](https://github.com/ilyamiro/nixos-configuration)** - Optional QuickShell profile source
- **[QuickShell](https://git.outfoxxed.me/quickshell/quickshell)** - Qt-based shell framework powering End-4
  - [QuickShell Documentation](https://quickshell.outfoxxed.me/)
  - [QuickShell GitHub Mirror](https://github.com/outfoxxed/quickshell)

### Core Technologies
- **[Hyprland](https://github.com/hyprwm/Hyprland)** - Dynamic tiling Wayland compositor
- **[CachyOS](https://github.com/CachyOS)** - Optimized Linux kernel with performance patches
- **[NixOS](https://nixos.org)** - Declarative, reproducible Linux distribution
- **[Home Manager](https://github.com/nix-community/home-manager)** - User environment management

### Additional Tools
- **[Zen Browser](https://github.com/zen-browser/desktop)** - Privacy-focused Firefox fork
- **[matugen](https://github.com/InioX/matugen)** - Material Design color scheme generator
- **[Stylix](https://github.com/danth/stylix)** - System-wide theming framework

## License

This configuration is provided as-is for personal use and reference.

---

<div align="center">

**Built with ❤️ by [Valo-Asura](https://github.com/Valo-Asura)**

**Last Updated**: May 2026 • **NixOS Version**: 26.05 (unstable) • **Kernel**: Linux 7.0.1

*Powered by [End-4 Illogical Impulse](https://github.com/end-4/illogical-impulse) & [QuickShell](https://git.outfoxxed.me/quickshell/quickshell)*

</div>
