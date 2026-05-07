{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.terminal;
in
{
  options.modules.terminal = {
    enable = lib.mkEnableOption "terminal emulator theming and ownership";
  };

  config = lib.mkIf cfg.enable {
    # Upstream illogical-flake links its own foot/kitty directories. Keep the
    # local terminal module as the only writer for those configs.
    xdg.configFile."foot".enable = lib.mkForce false;
    xdg.configFile."kitty".enable = lib.mkForce false;

    home.activation.migrateFootDirectory = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      set -euo pipefail
      foot_dir="$HOME/.config/foot"

      if [ -L "$foot_dir" ]; then
        foot_target="$(${pkgs.coreutils}/bin/readlink "$foot_dir" || true)"
        case "$foot_target" in
          /nix/store/*-home-manager-files/*)
            rm "$foot_dir"
            mkdir -p "$foot_dir"
            ;;
        esac
      fi
    '';

    home.activation.migrateKittyDirectory = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      set -euo pipefail
      kitty_dir="$HOME/.config/kitty"

      if [ -L "$kitty_dir" ]; then
        kitty_target="$(${pkgs.coreutils}/bin/readlink "$kitty_dir" || true)"
        case "$kitty_target" in
          /nix/store/*-home-manager-files/*)
            rm "$kitty_dir"
            mkdir -p "$kitty_dir"
            ;;
        esac
      fi
    '';

    programs.foot = {
      enable = true;
      settings = {
        main = {
          font = "JetBrainsMono Nerd Font:size=12";
          pad = "16x16 center";
          dpi-aware = "yes";
        };
        cursor = {
          style = "beam";
          blink = true;
          color = "7dd3fc 101317";
        };
        colors = {
          alpha = "0.96";
          foreground = "f0f3f5";
          background = "101317";
          regular0 = "0f1419";
          regular1 = "f87171";
          regular2 = "7bd88f";
          regular3 = "f2b56b";
          regular4 = "82aaff";
          regular5 = "c792ea";
          regular6 = "7dd3fc";
          regular7 = "d6dde3";
          bright0 = "4b5563";
          bright1 = "ff8a8a";
          bright2 = "9be8ab";
          bright3 = "ffd18a";
          bright4 = "a7c5ff";
          bright5 = "ddb6f2";
          bright6 = "a5e9ff";
          bright7 = "ffffff";
        };
      };
    };

    programs.kitty = {
      enable = true;
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 12;
      };
      settings = {
        shell = "${pkgs.zsh}/bin/zsh";
        term = "xterm-kitty";
        background = "#101317";
        foreground = "#f0f3f5";
        cursor = "#7dd3fc";
        cursor_text_color = "#101317";
        selection_background = "#263340";
        selection_foreground = "#ffffff";
        url_color = "#f2b56b";
        active_border_color = "#7dd3fc";
        inactive_border_color = "#263340";
        bell_border_color = "#f2b56b";
        tab_bar_style = "powerline";
        tab_bar_edge = "bottom";
        tab_bar_min_tabs = 1;
        active_tab_background = "#7dd3fc";
        active_tab_foreground = "#101317";
        inactive_tab_background = "#1c232b";
        inactive_tab_foreground = "#c5d0d8";
        window_padding_width = 12;
        background_opacity = "0.96";
        dynamic_background_opacity = true;
        enable_audio_bell = false;
        cursor_shape = "beam";
        cursor_blink_interval = "0.45";
        scrollback_lines = 10000;
        repaint_delay = 10;
        input_delay = 2;
        sync_to_monitor = true;
        color0 = "#0f1419";
        color1 = "#f87171";
        color2 = "#7bd88f";
        color3 = "#f2b56b";
        color4 = "#82aaff";
        color5 = "#c792ea";
        color6 = "#7dd3fc";
        color7 = "#d6dde3";
        color8 = "#4b5563";
        color9 = "#ff8a8a";
        color10 = "#9be8ab";
        color11 = "#ffd18a";
        color12 = "#a7c5ff";
        color13 = "#ddb6f2";
        color14 = "#a5e9ff";
        color15 = "#ffffff";
      };
      extraConfig = ''
        cursor_trail 1
        cursor_trail_decay 0.08 0.28
        confirm_os_window_close 0
        clipboard_control write-clipboard write-primary read-clipboard read-primary
        copy_on_select yes
        map ctrl+shift+c copy_to_clipboard
        map ctrl+shift+v paste_from_clipboard
        map shift+insert paste_from_clipboard
        map ctrl+insert copy_to_clipboard
        map super+c copy_to_clipboard
        map super+v paste_from_clipboard
        tab_powerline_style slanted
        active_tab_title_template  {tab.active_wd}
        inactive_tab_title_template  {tab.active_wd}
        tab_title_max_length 48
      '';
    };
  };
}
