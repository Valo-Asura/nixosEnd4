{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.secureBoot;
  keyDir = "${cfg.pkiBundle}/keys";
in
{
  config = lib.mkIf (cfg.enable && cfg.mode == "sbctl") {
    environment.systemPackages = [ pkgs.sbctl ];

    system.activationScripts.secureBootKeyCheck = ''
      if [ ! -d ${lib.escapeShellArg keyDir} ] || [ ! -f ${lib.escapeShellArg "${keyDir}/PK/PK.key"} ]; then
        echo "INFO: Secure Boot keys were not found in ${cfg.pkiBundle}"
        echo "Run:"
        echo "  sudo sbctl create-keys"
        echo "  sudo mkdir -p ${cfg.pkiBundle}"
        echo "  sudo cp -r /usr/share/secureboot/keys ${cfg.pkiBundle}/"
        echo "  sudo sbctl enroll-keys${lib.optionalString cfg.enrollMicrosoftKeys " --microsoft"}"
        echo "See modules/secure-boot/README.md for the full workflow."
      fi
    '';
  };
}
