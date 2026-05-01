# ═══════════════════════════════════════════════════════════════════════════════
# NixOS Quickshell Integration Module
# ═══════════════════════════════════════════════════════════════════════════════
# Integrates real-time system monitoring into the Illogical Impulse bar
# Consumes x15-hwmon JSON and adds CPU temperature/load data to Resources
# ═══════════════════════════════════════════════════════════════════════════════

{ config, lib, pkgs, ... }:

let
  cfg = config.modules.quickshellIntegration;

in
{
  # ═══════════════════════════════════════════════════════════════════════════
  # OPTIONS
  # ═══════════════════════════════════════════════════════════════════════════
  
  options.modules.quickshellIntegration = {
    enable = lib.mkEnableOption "Quickshell resource monitoring integration";
    
    updateInterval = lib.mkOption {
      type = lib.types.int;
      default = 2000;
      description = "Resource data staleness window in milliseconds";
    };
    
    showGpu = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show GPU temperature in widget";
    };
    
    showFan = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show fan speed in widget";
    };
  };

  # ═══════════════════════════════════════════════════════════════════════════
  # CONFIGURATION
  # ═══════════════════════════════════════════════════════════════════════════
  
  config = lib.mkIf cfg.enable {

    # ── Environment Packages ─────────────────────────────────────────────────
    home.packages = [
      (pkgs.writeShellScriptBin "quickshell-reload" ''
        #!${pkgs.bash}/bin/bash
        # Reload Quickshell configuration
        
        if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
          echo ">>> Reloading Quickshell..."
          
          # Kill existing quickshell
          pkill -f "quickshell" 2>/dev/null || true
          
          # Restart (usually triggered by session manager)
          sleep 1
          
          # Check status
          if pgrep -f "quickshell" > /dev/null; then
            echo "    [✓] Quickshell reloaded"
          else
            echo "    [!] Quickshell not running - may need manual restart"
          fi
        else
          echo "    [!] Not in Hyprland session"
        fi
      '')
    ];
    
  };
}
