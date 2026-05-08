{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.media;
in
{
  options.modules.media = {
    enable = lib.mkEnableOption "camera, microphone, PipeWire, and media tools";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      # Camera and microphone checks.
      snapshot
      cameractrls
      v4l-utils
      pwvucontrol
      crosspipe
      alsa-utils

      # Media playback.
      vlc
      ani-cli
    ];
  };
}
