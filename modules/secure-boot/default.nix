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
    enable = lib.mkEnableOption "Secure Boot with Lanzaboote";

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
    # Lanzaboote replaces systemd-boot with a Secure Boot-capable bootloader.
    # It signs the kernel, initrd, and boot files automatically on each rebuild.
    boot.loader.systemd-boot.enable = lib.mkForce false;

    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
    };

    # Ensure the PKI bundle directory exists and contains keys.
    # Keys must be generated manually before enabling Secure Boot:
    #   sudo sbctl create-keys
    #   sudo sbctl enroll-keys --microsoft
    # Then copy /usr/share/secureboot/keys/{PK,KEK,db}/* to /etc/secureboot/
    system.activationScripts.secureBootCheck = lib.mkIf cfg.enable ''
      if [ ! -d /etc/secureboot ] || [ ! -f /etc/secureboot/keys/PK/PK.key ]; then
        echo "WARNING: Secure Boot keys not found in /etc/secureboot/"
        echo "Generate keys with: sudo sbctl create-keys"
        echo "Enroll keys with: sudo sbctl enroll-keys --microsoft"
      fi
    '';

    environment.systemPackages = with pkgs; [
      sbctl # Secure Boot key management utility
    ];
  };
}
