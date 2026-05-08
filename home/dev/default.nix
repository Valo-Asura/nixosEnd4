{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./git.nix
    ./python.nix
    ./ides.nix
    ./ai.nix
  ];

  options.modules.dev = {
    enable = lib.mkEnableOption "declarative developer profile";

    git.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Git and diff tooling.";
    };

    python.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the global Python developer toolchain.";
    };

    ides.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable IDE packages and declarative VS Code settings.";
    };

    ai.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable AI/developer CLI tools.";
    };
  };

  config = lib.mkIf config.modules.dev.enable {
    home.packages = with pkgs; [
      delta
      lazygit
      nil
      nixfmt
      uv
    ];
  };
}
