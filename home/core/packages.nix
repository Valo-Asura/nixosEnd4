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
      nil
      nixfmt
      uv
      fzf
      bottom
      lazygit
      delta
      jq
      curl

      # Nix and AI tooling.
      ollama
      (pkgs."claude-code")
      python3
      python3Packages.conda
      python3Packages.jupyterlab

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
      pavucontrol
      blueman
      telegram-desktop
      wtype
      nemo
      yazi

      # Media.
      ani-cli
      vlc

      # Terminals and theming.
      foot
      kitty
      dart-sass
      nerd-fonts.jetbrains-mono
    ];
  };
}
