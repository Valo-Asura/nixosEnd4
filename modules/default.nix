{ ... }:

{
  imports = [
    ./boot.nix
    ./battery-care.nix
    ./performance.nix
    ./performance-enhanced.nix      # CachyOS-style kernel 7+ optimization
    ./nvidia.nix
    ./portal.nix
    ./ollama.nix
    ./hardware-monitor.nix            # Hardware monitoring & fan control
    ./i3-session.nix                  # X11 fallback session with Hyprland-like binds
    ./system-cleanup.nix              # System cleanup & restructuring
  ];
}
