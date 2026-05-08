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
    # Keep the local terminal module as the only writer for foot/kitty configs.
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
          color = "ff8f86 170d0f";
        };
        colors = {
          alpha = "0.94";
          foreground = "f7d8d1";
          background = "170d0f";
          regular0 = "140c0d";
          regular1 = "f25f68";
          regular2 = "d7c76f";
          regular3 = "f2bf63";
          regular4 = "d98f7a";
          regular5 = "f09aa5";
          regular6 = "ff8f86";
          regular7 = "ead0ca";
          bright0 = "514143";
          bright1 = "ff747d";
          bright2 = "e8d98a";
          bright3 = "ffd17a";
          bright4 = "f0a58e";
          bright5 = "ffb0b8";
          bright6 = "ffaaa1";
          bright7 = "fff4ef";
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
        background = "#170d0f";
        foreground = "#f7d8d1";
        cursor = "#ff8f86";
        cursor_text_color = "#170d0f";
        selection_background = "#3a2024";
        selection_foreground = "#fff4ef";
        url_color = "#f2bf63";
        active_border_color = "#ff8f86";
        inactive_border_color = "#3a2024";
        bell_border_color = "#f2bf63";
        tab_bar_style = "powerline";
        tab_bar_edge = "bottom";
        tab_bar_min_tabs = 1;
        active_tab_background = "#ff8f86";
        active_tab_foreground = "#170d0f";
        inactive_tab_background = "#281719";
        inactive_tab_foreground = "#d8b8b2";
        window_padding_width = 10;
        background_opacity = "0.94";
        dynamic_background_opacity = true;
        enable_audio_bell = false;
        cursor_shape = "beam";
        cursor_blink_interval = "0.45";
        scrollback_lines = 10000;
        repaint_delay = 10;
        input_delay = 2;
        sync_to_monitor = true;
        color0 = "#140c0d";
        color1 = "#f25f68";
        color2 = "#d7c76f";
        color3 = "#f2bf63";
        color4 = "#d98f7a";
        color5 = "#f09aa5";
        color6 = "#ff8f86";
        color7 = "#ead0ca";
        color8 = "#514143";
        color9 = "#ff747d";
        color10 = "#e8d98a";
        color11 = "#ffd17a";
        color12 = "#f0a58e";
        color13 = "#ffb0b8";
        color14 = "#ffaaa1";
        color15 = "#fff4ef";
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
