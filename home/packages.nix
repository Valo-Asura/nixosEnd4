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
      yazi
      jq
      curl
      ollama
      (pkgs."claude-code")
      python3Packages.conda
      python3Packages.jupyterlab
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

      ani-cli
      vlc

      foot
      kitty
      dart-sass
      nerd-fonts.jetbrains-mono
    ];
  };
}
