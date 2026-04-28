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
      extraPortals = lib.mkForce [
        config.programs.hyprland.portalPackage
        pkgs.xdg-desktop-portal-gtk
      ];
    };
  };
}
