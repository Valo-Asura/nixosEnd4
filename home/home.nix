{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./packages.nix
    ./browser.nix
    ./ide.nix
    ./mimeapps.nix
    ./git.nix
    ./yazi.nix
    ./nanobot.nix
    ./hyprland.nix
    ./shell/base.nix
    ./shell/zsh.nix
  ];

  home.homeDirectory = "/home/asura";
  home.stateVersion = "25.11";

  modules = {
    packages.enable = true;
    browser.enable = true;
    ide.enable = true;
    mimeapps.enable = true;
    git.enable = true;
    yazi.enable = true;
    nanobot.enable = true;
    shell.enable = true;
    hyprland.enable = true;
  };

  programs.illogical-impulse = {
    enable = true;
    dotfiles = {
      fish.enable = false; # using local zsh/kitty stack instead
      kitty.enable = false; # use the local kitty config and launch zsh
      starship.enable = true;
    };
  };

  # Keep Stylix at the system level only; shell/theme ownership lives with
  # Illogical Impulse + matugen in Home Manager.
  stylix.enable = false;

  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  gtk = {
    enable = true;
    theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3-dark";
    };
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "adw-gtk3-dark";
  };

  home.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
    GTK_THEME = "adw-gtk3-dark";
    GIO_EXTRA_MODULES = "${pkgs.gvfs}/lib/gio/modules:${pkgs.glib-networking}/lib/gio/modules";
    # illogical-flake has a conflict between common.nix ("") and qt.nix ("kvantum");
    # force the intended value here to resolve the evaluation error.
    QT_STYLE_OVERRIDE = lib.mkForce "kvantum";
    QSG_RENDER_LOOP = "basic";
  };

  home.activation.enforceGtkDark = lib.hm.dag.entryAfter [ "dconfSettings" ] ''
    set -euo pipefail
    ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true
    ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark || true
  '';

  # Restore the upstream Kvantum theme dir now that Home Manager Stylix
  # is no longer managing Qt theming.
  xdg.configFile."Kvantum".enable = lib.mkForce true;
  # The upstream dotfiles layer also ships ~/.config/foot; disable that copy so
  # the local programs.foot block is the only owner of Foot configuration.
  xdg.configFile."foot".enable = lib.mkForce false;
  # Upstream illogical-flake links a fish-based kitty directory unconditionally.
  # Disable it so the local HM kitty config can launch zsh instead.
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
        pad = "18x18 center";
      };
      cursor = {
        style = "beam";
        blink = true;
        color = "ff6b84 120b10";
      };
      colors = {
        alpha = "0.96";
        foreground = "f7d7dd";
        background = "120b10";
        regular0 = "191018";
        regular1 = "ff4d6d";
        regular2 = "ff6b84";
        regular3 = "ff7f50";
        regular4 = "c65d7b";
        regular5 = "e58fb0";
        regular6 = "f2a7b8";
        regular7 = "f7d7dd";
        bright0 = "2a1620";
        bright1 = "ff5a78";
        bright2 = "ff7f97";
        bright3 = "ff9c66";
        bright4 = "d57390";
        bright5 = "f0a2c0";
        bright6 = "f8b8c7";
        bright7 = "fff0f3";
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
      background = "#120b10";
      foreground = "#f7d7dd";
      cursor = "#ff6b84";
      cursor_text_color = "#120b10";
      selection_background = "#3a1c2a";
      selection_foreground = "#ffe9ee";
      tab_bar_style = "powerline";
      tab_bar_edge = "bottom";
      tab_bar_min_tabs = 1;
      active_tab_background = "#ff4d6d";
      active_tab_foreground = "#120b10";
      inactive_tab_background = "#2a1620";
      inactive_tab_foreground = "#e3c1c9";
      window_padding_width = 14;
      enable_audio_bell = false;
      cursor_shape = "beam";
      cursor_blink_interval = "0.45";
    };
    extraConfig = ''
      cursor_trail 2
      cursor_trail_decay 0.12 0.45
      confirm_os_window_close 0
      clipboard_control write-clipboard write-primary read-clipboard read-primary
      copy_on_select yes
      map ctrl+shift+c copy_to_clipboard
      map ctrl+shift+v paste_from_clipboard
      map shift+insert paste_from_clipboard
      map ctrl+insert copy_to_clipboard
      map super+c copy_to_clipboard
      map super+v paste_from_clipboard
      tab_powerline_style round
      active_tab_title_template 󰉋  {tab.active_wd}
      inactive_tab_title_template 󰉋  {tab.active_wd}
      tab_title_max_length 48
    '';
  };

  programs.home-manager.enable = true;
}
