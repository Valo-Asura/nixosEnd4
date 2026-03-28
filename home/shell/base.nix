{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.shell;
  ffetchTheme = pkgs.writeShellScriptBin "ffetch-theme" ''
    set -euo pipefail

    img_dir="$HOME/Pictures/fastfetch"
    pinned="$HOME/.config/fastfetch/current-image"
    img=""
    cfg="$HOME/.config/fastfetch/config.jsonc"

    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.config/fastfetch"

    if [ -f "$pinned" ]; then
      candidate="$(${pkgs.coreutils}/bin/cat "$pinned" 2>/dev/null || true)"
      if [ -n "$candidate" ] && [ -f "$candidate" ]; then
        img="$candidate"
      fi
    fi

    if [ -z "$img" ] && [ -d "$img_dir" ]; then
      img="$(${pkgs.findutils}/bin/find "$img_dir" -maxdepth 2 -type f \
        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.avif' \) \
        2>/dev/null | ${pkgs.coreutils}/bin/sort | ${pkgs.coreutils}/bin/head -n1 || true)"
    fi

    if [ -z "$img" ] && [ -f "$HOME/.config/quickshell/ii/assets/images/default_wallpaper.png" ]; then
      img="$HOME/.config/quickshell/ii/assets/images/default_wallpaper.png"
    fi

    if [ -n "$img" ]; then
      printf '%s\n' "$img" > "$pinned"

      run_fastfetch_with_logo() {
        ${pkgs.fastfetch}/bin/fastfetch --config "$cfg" "$@" \
          --logo-width 30 \
          --logo-height 16 \
          --logo-preserve-aspect-ratio true
      }

      # In kitty, prefer kitty graphics protocol for full quality logos.
      if [ -n "''${KITTY_WINDOW_ID:-}" ] || [ "''${TERM:-}" = "xterm-kitty" ]; then
        run_fastfetch_with_logo --kitty-direct "$img" && exit 0
        run_fastfetch_with_logo --kitty "$img" && exit 0
      fi

      # Prefer sixel for terminals with decent image support.
      case "''${TERM:-}" in
        foot*|xterm-ghostty*)
          run_fastfetch_with_logo --sixel "$img" && exit 0
          ;;
      esac

      # Broad fallback chain for mixed terminals.
      run_fastfetch_with_logo --iterm "$img" && exit 0
      run_fastfetch_with_logo --sixel "$img" && exit 0
      run_fastfetch_with_logo --chafa "$img" && exit 0
    fi

    exec ${pkgs.fastfetch}/bin/fastfetch --config "$cfg"
  '';
in
{
  options.modules.shell = {
    enable = lib.mkEnableOption "shell stack (zsh + terminal tooling)";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ ffetchTheme ];

    xdg.configFile."fastfetch/config.jsonc".source = ./fastfetch.jsonc;

    programs.carapace = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.atuin = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        auto_sync = false;
      };
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableZshIntegration = true;
    };

    programs.zoxide = {
      enable = true;
      options = [
        "--cmd"
        "z"
      ];
      enableZshIntegration = true;
    };

    # programs.starship is disabled here because illogical-impulse manages
    # starship.toml via dotfiles.starship.enable = true in home.nix.
    # Re-enable this block (and set dotfiles.starship.enable = false) to
    # switch back to the custom starship config.
    programs.starship = {
      enable = lib.mkForce false;
    };

    programs.zellij.enable = true;
    xdg.configFile."zellij/config.kdl".source = ./config.kdl;
  };
}
