{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.yazi;
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
        gruvbox-dark = ./yazi/flavors/gruvbox-dark.yazi;
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
