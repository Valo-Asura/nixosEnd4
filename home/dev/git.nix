{ config, lib, ... }:

let
  cfg = config.modules.dev.git;
in
{
  config = lib.mkIf (config.modules.dev.enable && cfg.enable) {
    programs.delta = {
      enable = true;
      enableGitIntegration = true;
    };

    programs.git = {
      enable = true;

      signing.signByDefault = false;

      settings = {
        user.name = "asura";
        user.email = "asura@x15xs.local";

        init.defaultBranch = "main";
        pull.rebase = false;
      };
    };
  };
}
