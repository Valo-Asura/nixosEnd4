{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.secureBoot;
in
{
  options.modules.secureBoot = {
    enable = lib.mkEnableOption "Secure Boot preparation (sbctl only)";

    useLanzaboote = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Lanzaboote for automatic kernel signing.
        Requires lanzaboote flake input to be added to flake.nix.
        See modules/secure-boot/README.md for setup instructions.
      '';
    };

    publicKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to the Secure Boot public key (PK.der)";
    };

    privateKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to the Secure Boot private key (PK.key)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Install sbctl for Secure Boot key management
    environment.systemPackages = with pkgs; [
      sbctl # Secure Boot key management utility
    ];

    # Lanzaboote integration (requires flake input)
    # To enable:
    # 1. Add lanzaboote to flake.nix inputs
    # 2. Import lanzaboote.nixosModules.lanzaboote in host config
    # 3. Set modules.secureBoot.useLanzaboote = true
    assertions = [
      {
        assertion = !cfg.useLanzaboote || config.boot ? lanzaboote;
        message = ''
          modules.secureBoot.useLanzaboote is enabled but boot.lanzaboote is not available.
          Add lanzaboote to your flake inputs:
            inputs.lanzaboote = {
              url = "github:nix-community/lanzaboote";
              inputs.nixpkgs.follows = "nixpkgs";
            };
          Then import it in your host configuration.
        '';
      }
    ];

    # Ensure the PKI bundle directory exists and contains keys.
    # Keys must be generated manually before enabling Secure Boot:
    #   sudo sbctl create-keys
    #   sudo sbctl enroll-keys --microsoft
    system.activationScripts.secureBootCheck = ''
      if [ ! -d /etc/secureboot ] || [ ! -f /etc/secureboot/keys/PK/PK.key ]; then
        echo "INFO: Secure Boot keys not found in /etc/secureboot/"
        echo "To set up Secure Boot:"
        echo "  1. sudo sbctl create-keys"
        echo "  2. sudo mkdir -p /etc/secureboot"
        echo "  3. sudo cp -r /usr/share/secureboot/keys /etc/secureboot/"
        echo "  4. sudo sbctl enroll-keys --microsoft"
        echo "See modules/secure-boot/README.md for details"
      fi
    '';
  };
}
