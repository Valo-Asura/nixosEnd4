{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./inventory.nix
    ./battery-care.nix
    ./nvidia.nix
    ./hardware-monitor.nix
  ];
}
