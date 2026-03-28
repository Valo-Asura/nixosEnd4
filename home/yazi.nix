{ config, lib, pkgs, ... }:

let
  cfg = config.modules.yazi;

  gruvboxDarkFlavor = pkgs.fetchFromGitHub {
    owner = "gmvar";
    repo = "gruvbox-dark.yazi";
    rev = "8f520a458e0c1a1ee7c8d14876233eb16a22d0f3";
    hash = "sha256-18b+5t0dZVUrS2JWfILR+wWVAcWg+UzJ4dWb5Xj9B+E=";
  };
in
{
  options.modules.yazi = {
    enable = lib.mkEnableOption "yazi file manager";
  };

  config = lib.mkIf cfg.enable {
    programs.yazi = {
      enable = true;
      enableZshIntegration = true;
      shellWrapperName = "y";

      flavors = {
        gruvbox-dark = gruvboxDarkFlavor;
      };

      theme = {
        flavor = {
          dark = "gruvbox-dark";
          light = "gruvbox-dark";
        };
      };

      plugins = {
        full-border = pkgs.yaziPlugins.full-border;
        git = pkgs.yaziPlugins.git;
        starship = pkgs.yaziPlugins.starship;
      };
    };
  };
}
