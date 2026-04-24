{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.programs.illogical-impulse;
  iiInputs = inputs.illogical-flake.inputs;
  iiPath = inputs.illogical-flake.outPath;
in
{
  imports = [
    (import "${iiPath}/home-modules/fonts.nix" iiInputs)
    ./packages.nix
    ./qt.nix
    (import "${iiPath}/home-modules/environment.nix" iiInputs)
    (import "${iiPath}/home-modules/dotfiles.nix" iiInputs)
    ./settings.nix
  ];

  options.programs.illogical-impulse = {
    enable = mkEnableOption "Enable the Illogical Impulse Hyprland configuration";

    internal = {
      pythonEnv = mkOption {
        type = types.package;
        internal = true;
        description = "Python environment for QuickShell (internal use only)";
      };

      features = {
        kde = mkOption {
          type = types.bool;
          default = false;
          internal = true;
          description = "Enable non-essential KDE desktop integration packages.";
        };

        microtex = mkOption {
          type = types.bool;
          default = false;
          internal = true;
          description = "Reserved toggle for MicroTeX support when the upstream HM module exposes it.";
        };
      };
    };
  };
}
