{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.portal;
in
{
  options.modules.portal = {
    enable = lib.mkEnableOption "PipeWire and XDG desktop portals";
  };

  config = lib.mkIf cfg.enable {
    security.rtkit.enable = true;
    services.gvfs.enable = true;
    services.udisks2.enable = true;

    services.pulseaudio.enable = false;

    services.pipewire = {
      enable = true;
      audio.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    xdg.portal = {
      enable = true;
      # programs.hyprland.enable already inserts the Hyprland portal package;
      # only add the GTK fallback portal here to avoid the duplicate
      # 'org.freedesktop.impl.portal.desktop.hyprland' dbus service warning.
      extraPortals = lib.mkForce [
        pkgs.xdg-desktop-portal-gtk
      ];
    };
  };
}
