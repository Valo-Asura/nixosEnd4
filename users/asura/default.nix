{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    # Shared base tooling.
    ../../home/core/packages.nix

    # User-facing applications.
    ../../home/apps/browser.nix
    ../../home/apps/media.nix
    ../../home/apps/mimeapps.nix
    ../../home/apps/yazi.nix

    # Development workflow.
    ../../home/dev

    # Desktop/session behavior.
    ../../home/desktop/hyprland.nix
    ../../home/desktop/quickshell # Quickshell profile, clipboard, and resource integration

    # Shell environment.
    ../../home/shell/base.nix
    ../../home/shell/terminal.nix
    ../../home/shell/zsh.nix
  ];

  home.homeDirectory = "/home/asura";
  home.stateVersion = "25.11";

  modules = {
    packages.enable = true;
    browser.enable = true;
    media.enable = true;
    mimeapps.enable = true;
    yazi.enable = true;
    shell.enable = true;
    terminal.enable = true;
    hyprland.enable = true;

    dev = {
      enable = true;
      git.enable = true;
      python.enable = true;
      ides.enable = true;
      ai.enable = true;
    };

    quickshell = {
      enable = true;
      activeProfile = "end4";
      installIlyamiroProfile = true;
      lowResource = true;
      pollInterval = 10000;
      updateInterval = 2000;
      showGpu = true;
      showFan = true;
    };
  };

  # Keep Stylix at the system level only; shell/theme ownership lives with
  # the local QuickShell + matugen profile in Home Manager.
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

  dconf.settings."org/blueman/general" = {
    plugin-list = [ "!GameControllerWakelock" ];
    symbolic-status-icons = true;
  };

  home.sessionVariables = {
    BROWSER = "google-chrome-stable";
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
    GTK_THEME = "adw-gtk3-dark";
    GIO_EXTRA_MODULES = "${pkgs.gvfs}/lib/gio/modules:${pkgs.glib-networking}/lib/gio/modules";
    QT_STYLE_OVERRIDE = lib.mkForce "kvantum";
    QSG_RENDER_LOOP = "basic";
  };

  home.activation.enforceGtkDark = lib.hm.dag.entryAfter [ "dconfSettings" ] ''
    set -euo pipefail
    ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true
    ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark || true
  '';

  # i3 config: ~/.config/i3/ directory exists but is empty, causing i3 to ask
  # "create new config or use defaults". Provide the file so i3 finds it first.
  xdg.configFile."i3/config".source = ../../home/desktop/i3/config;
  xdg.configFile."autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
  xdg.configFile."autostart/geoclue-demo-agent.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
  xdg.configFile."autostart/gnome-keyring-pkcs11.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
  xdg.configFile."autostart/gnome-keyring-secrets.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';

  # Blueman is enabled at system level (services.blueman.enable = true)
  # so we don't need a user service
  # systemd.user.services.blueman-applet = {
  #   Unit = {
  #     Description = "Blueman tray applet";
  #     PartOf = [ "graphical-session.target" ];
  #     After = [ "graphical-session.target" ];
  #   };
  #
  #   Service = {
  #     Type = "dbus";
  #     BusName = "org.blueman.Applet";
  #     ExecStart = "${pkgs.blueman}/bin/blueman-applet";
  #     Restart = "on-failure";
  #   };
  #
  #   Install.WantedBy = [ "graphical-session.target" ];
  # };

  programs.home-manager.enable = true;
}
