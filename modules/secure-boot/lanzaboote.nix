{
  config,
  lib,
  options,
  ...
}:

let
  cfg = config.modules.secureBoot;
  hasLanzabooteOption = lib.hasAttrByPath [ "boot" "lanzaboote" ] options;
in
{
  config = lib.mkIf (cfg.enable && cfg.mode == "lanzaboote") (
    {
      assertions = [
        {
          assertion = hasLanzabooteOption;
          message = ''
            modules.secureBoot.mode = "lanzaboote" requires the Lanzaboote module
            to be imported from your flake inputs first.
          '';
        }
        {
          assertion = !(config.boot.loader.limine.enable or false);
          message = ''
            Lanzaboote cannot be layered on top of the current Limine setup.
            Switch the host to a systemd-boot-based flow before enabling this mode.
          '';
        }
      ];
    }
    // lib.optionalAttrs hasLanzabooteOption {
      boot.lanzaboote = {
        enable = true;
        pkiBundle = cfg.pkiBundle;
      };
    }
  );
}
