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
    ./system-cleanup.nix              # System cleanup & restructuring
    ./quickshell-integration.nix    # Quickshell UI integration
  ];
}
