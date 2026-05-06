{ lib, ... }:

{
  options.modules.secureBoot = {
    enable = lib.mkEnableOption "modular Secure Boot support";

    mode = lib.mkOption {
      type = lib.types.enum [ "sbctl" "lanzaboote" ];
      default = "sbctl";
      description = ''
        Secure Boot workflow to prepare:
        - `sbctl`: keep the current bootloader and manage keys/signing manually.
        - `lanzaboote`: switch to Lanzaboote once its flake input is imported.
      '';
    };

    pkiBundle = lib.mkOption {
      type = lib.types.str;
      default = "/etc/secureboot";
      description = "Directory that stores the Secure Boot PK/KEK/db key bundle.";
    };

    enrollMicrosoftKeys = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Document the Microsoft-compatible enrollment flow for dual-boot systems.";
    };
  };
}
