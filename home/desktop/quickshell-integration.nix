# ═══════════════════════════════════════════════════════════════════════════════
# NixOS Quickshell Integration Module
# ═══════════════════════════════════════════════════════════════════════════════
# Integrates real-time system monitoring into the Illogical Impulse bar
# Consumes x15-hwmon JSON and adds CPU temperature/load data to Resources
# ═══════════════════════════════════════════════════════════════════════════════

{ config, lib, pkgs, ... }:

let
  cfg = config.modules.quickshellIntegration;

  resourceServicePath = pkgs.replaceVars ./end4/overrides/ResourceService.qml {
    staleAfterMs = toString (cfg.updateInterval * 3);
  };

  resourcesPopupPath = pkgs.replaceVars ./end4/overrides/ResourcesPopup.qml {
    showGpu = if cfg.showGpu then "true" else "false";
    showFan = if cfg.showFan then "true" else "false";
  };

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
    
    # ── Home Manager Configuration ───────────────────────────────────────────
    home.file = lib.mkIf cfg.enable {
      ".config/quickshell/ii/modules/ii/bar/Resources.qml".source =
        ./end4/overrides/Resources.qml;
      ".config/quickshell/ii/modules/ii/bar/ResourcesPopup.qml".source =
        resourcesPopupPath;
      ".config/quickshell/ii/services/ResourceService.qml".source =
        resourceServicePath;
    };
  };
}
