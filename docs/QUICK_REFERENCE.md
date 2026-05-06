# NixOS x15xs Quick Reference

**Last Updated**: May 2026

---

## System Management

### Rebuild System
```bash
# Apply changes
sudo nixos-rebuild switch --flake /etc/nixos#x15xs

# Test without activating
sudo nixos-rebuild dry-build --flake /etc/nixos#x15xs

# Rollback to previous generation
sudo nixos-rebuild switch --rollback
```

### Generations
```bash
# List all generations
sudo nixos-rebuild list-generations

# Boot specific generation (from Limine menu)
# Select generation at boot time
```

### Updates
```bash
# Update flake inputs
nix flake update /etc/nixos

# Update specific input
nix flake lock --update-input nixpkgs /etc/nixos

# Rebuild after update
sudo nixos-rebuild switch --flake /etc/nixos#x15xs
```

---

## Hyprland Keybindings

### Applications
| Key | Action |
|-----|--------|
| `Super` (release) | Launcher |
| `Super+Q` | Kill window |
| `Super+H` | Exit Hyprland |
| `Super+T` | Terminal (Kitty) |
| `Super+B` | Browser (Chrome) |
| `Super+C` | Code editor (VSCode) |
| `Super+E` | Telegram |
| `Super+F` | File manager |

### Window Management
| Key | Action |
|-----|--------|
| `Super+V` | Toggle floating |
| `Super+J` | Toggle split |
| `Super+Arrows` | Move focus |
| `Super+Shift+Arrows` | Move window |
| `Super+Tab` | Resize mode |
| `Super+Shift+Tab` | Workspace overview |

### Workspaces
| Key | Action |
|-----|--------|
| `Super+1-9` | Switch to workspace |
| `Super+Shift+1-9` | Move window to workspace |
| `3-finger swipe left/right` | Previous/next workspace |

### Utilities
| Key | Action |
|-----|--------|
| `Super+L` or `Ctrl+L` | Lock screen |
| `Super+P` | Wallpaper selector |
| `Super+Shift+P` | Random wallpaper |
| `Super+Shift+C` | Clipboard history |
| `Super+Shift+E` | Emoji picker |
| `Super+F2` | Night light toggle |
| `Print` | Screenshot (selection) |
| `Super+Print` | Screenshot (full) |

### Hardware Keys
| Key | Action |
|-----|--------|
| `XF86AudioMute` | Toggle mute |
| `XF86AudioRaiseVolume` | Volume up |
| `XF86AudioLowerVolume` | Volume down |
| `XF86MonBrightnessUp` | Brightness up |
| `XF86MonBrightnessDown` | Brightness down |
| `XF86AudioPlay` | Play/pause |
| `XF86AudioNext` | Next track |
| `XF86AudioPrev` | Previous track |

---

## i3 Keybindings

### Applications
| Key | Action |
|-----|--------|
| `Super+Space` or `Super+D` | Launcher |
| `Super+Q` | Kill window |
| `Super+H` | Exit i3 |
| `Super+T` | Terminal |
| `Super+B` | Browser |
| `Super+C` | Code editor |
| `Super+E` | Telegram |
| `Super+F` | File manager |

### Window Management
| Key | Action |
|-----|--------|
| `Super+V` | Toggle floating |
| `Super+J` | Toggle split |
| `Super+Arrows` | Move focus |
| `Super+Shift+Arrows` | Move window |
| `Super+Tab` | Resize mode |
| `Super+Shift+Tab` | Window overview |

### Workspaces
| Key | Action |
|-----|--------|
| `Super+1-9` | Switch to workspace |
| `Super+Shift+1-9` | Move window to workspace |

### Utilities
| Key | Action |
|-----|--------|
| `Super+L` or `Ctrl+L` | Lock screen |
| `Super+P` | Wallpaper menu |
| `Super+Shift+P` | Random wallpaper |
| `Super+Shift+C` | Clipboard history |
| `Super+Shift+E` | Emoji picker |
| `Super+F2` | Night light toggle |
| `Print` | Screenshot |

---

## Hardware Monitoring

### Check Temperatures
```bash
# CPU temperature
sensors | grep Core

# GPU temperature
nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader

# All sensors
sensors
```

### Fan Control
```bash
# Check fan status
sudo nbfc status

# Set fan speed (0-100%)
sudo nbfc set -s 50

# Auto mode
sudo nbfc set -a
```

### Battery
```bash
# Check battery status
cat /sys/class/power_supply/BAT0/capacity
cat /sys/class/power_supply/BAT0/status

# Check charge limit
cat /sys/class/power_supply/BAT0/charge_control_end_threshold
```

---

## GPU Management

### Check Active GPU
```bash
# NVIDIA GPU info
nvidia-smi

# List all GPUs
lspci | grep VGA
```

### Run on NVIDIA GPU
```bash
# Use nvidia-offload wrapper
nvidia-offload <application>

# Or set environment variables
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia <application>
```

---

## Ollama (Local LLM)

### Service Management
```bash
# Check status
systemctl status ollama

# Restart service
sudo systemctl restart ollama
```

### Model Management
```bash
# List installed models
ollama list

# Pull new model
ollama pull qwen3:4b

# Remove model
ollama rm <model>
```

### Usage
```bash
# Chat with model
ollama run phi4-mini:3.8b

# Web UI
# Open browser to http://localhost:8080
```

---

## Maintenance

### Cleanup
```bash
# Delete old generations (>7 days)
sudo nix-collect-garbage -d

# Optimize nix store
sudo nix-store --optimise

# Clean journal logs
sudo journalctl --vacuum-size=500M
```

### Logs
```bash
# System logs
journalctl -xe

# Specific service
journalctl -u <service>

# Follow logs
journalctl -f
```

### Performance
```bash
# Boot time analysis
systemd-analyze
systemd-analyze blame

# Memory usage
free -h

# Disk usage
df -h
```

---

## Troubleshooting

### Hyprland Issues
```bash
# Check Hyprland logs
journalctl --user -u hyprland

# Reload Hyprland config
hyprctl reload

# Check gesture settings
hyprctl getoption gestures:workspace_swipe_distance
```

### NVIDIA Issues
```bash
# Check NVIDIA driver
nvidia-smi

# Check kernel modules
lsmod | grep nvidia

# Reload NVIDIA modules
sudo modprobe -r nvidia_drm nvidia_modeset nvidia
sudo modprobe nvidia nvidia_modeset nvidia_drm
```

### greetd Issues
```bash
# Check greetd status
systemctl status greetd

# View greetd logs
journalctl -u greetd

# Clear tuigreet cache
sudo rm /var/cache/tuigreet/lastsession-*
```

### Boot Issues
```bash
# Boot previous generation from Limine menu
# Select older generation at boot

# Or rollback
sudo nixos-rebuild switch --rollback
```

---

## File Locations

### System Configuration
```
/etc/nixos/
├── flake.nix                 # Main flake
├── hosts/x15xs/default.nix   # Host config
├── modules/                  # System modules
├── home/                     # User config
└── docs/                     # Documentation
```

### User Configuration
```
~/.config/
├── hypr/                     # Hyprland config
├── i3/                       # i3 config
├── kitty/                    # Terminal config
└── quickshell/               # End-4 shell
```

### Logs
```
/var/log/                     # System logs
~/.local/share/               # User logs
```

---

## Performance Profiles

### Switch Performance Mode
```nix
# In hosts/x15xs/default.nix
modules.performance.profile = "max";      # Maximum performance
modules.performance.profile = "balanced"; # Balanced (default)
modules.performance.profile = "cool";     # Quiet/cool
```

### Profiles Comparison
| Profile | CPU Governor | Fan Speed | Battery Life |
|---------|--------------|-----------|--------------|
| max | performance | High | ~3h |
| balanced | schedutil | Auto | ~5.8h |
| cool | powersave | Low | ~7h |

---

## Useful Commands

### Nix
```bash
# Search packages
nix search nixpkgs <package>

# Show package info
nix eval nixpkgs#<package>.meta.description

# Enter development shell
nix develop

# Format Nix files
nix fmt
```

### System Info
```bash
# NixOS version
nixos-version

# Kernel version
uname -r

# Hardware info
lshw -short
```

---

## Emergency Recovery

### Boot Fails
1. Select previous generation from Limine menu
2. Boot into system
3. Investigate issue: `journalctl -xb`
4. Fix configuration
5. Rebuild: `sudo nixos-rebuild switch --flake /etc/nixos#x15xs`

### System Unresponsive
1. Switch to TTY: `Ctrl+Alt+F2`
2. Login as user
3. Check logs: `journalctl -xe`
4. Restart problematic service: `sudo systemctl restart <service>`
5. Or reboot: `sudo reboot`

### Broken Configuration
```bash
# Rollback to last working generation
sudo nixos-rebuild switch --rollback

# Or boot previous generation from Limine menu
```

---

## Documentation

- **System Architecture**: `docs/SYSTEM_ARCHITECTURE.md`
- **Project Summary**: `docs/PROJECT_SUMMARY.md`
- **Fixes & Improvements**: `docs/FIXES_AND_IMPROVEMENTS.md`
- **Hyprland Controls**: `HYPRLAND_CONTROLS.md`
- **End-4 Settings**: `END4_SETTINGS.md`
- **Secure Boot Setup**: `modules/secure-boot/README.md`

---

## Support

### Resources
- NixOS Manual: https://nixos.org/manual/nixos/stable/
- Hyprland Wiki: https://wiki.hyprland.org/
- NixOS Discourse: https://discourse.nixos.org/
- GitHub Issues: Check flake input repositories

### Local Documentation
```bash
# View documentation
cat /etc/nixos/docs/SYSTEM_ARCHITECTURE.md
cat /etc/nixos/docs/QUICK_REFERENCE.md
```

---

**Last Updated**: May 2026  
**Version**: 1.0  
**Maintainer**: Asura
