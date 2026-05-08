{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.packages;
in
{
  options.modules.packages = {
    enable = lib.mkEnableOption "desktop and CLI package set";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      # Core CLI.
      eza
      bat
      fd
      ripgrep
      zoxide
      direnv
      fzf
      bottom
      jq
      curl

      # Desktop helpers.
      networkmanager
      playerctl
      brightnessctl
      pamixer
      fastfetch
      grim
      slurp
      wf-recorder
      wl-clipboard
      cliphist
      libnotify
      telegram-desktop
      wtype
      nemo
      yazi

      # Terminals and theming.
      foot
      kitty
      dart-sass
      nerd-fonts.jetbrains-mono
    ];
  };
}
