{ config, lib, ... }:

let
  cfg = config.modules.git;
in
{
  options.modules.git = {
    enable = lib.mkEnableOption "git config";
  };

  config = lib.mkIf cfg.enable {
    programs.delta = {
      enable = true;
      enableGitIntegration = true;
    };

    programs.git = {
      enable = true;

      signing = {
        key = "TODO-REPLACE-WITH-YOUR-GPG-KEY";
        signByDefault = false;
      };

      settings = {
        user.name = "asura";
        user.email = "asura@x15xs.local";

        init.defaultBranch = "main";
        pull.rebase = false;
      };
    };
  };
}
