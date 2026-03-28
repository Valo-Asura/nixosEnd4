{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.browser;
in
{
  options.modules.browser = {
    enable = lib.mkEnableOption "browser package set and profile tuning";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      zen-browser
      brave
    ];

    programs.firefox.enable = lib.mkForce false;

    home.activation.configureBraveProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -euo pipefail
      brave_dir="$HOME/.config/BraveSoftware/Brave-Browser"
      prefs="$brave_dir/Default/Preferences"
      local_state="$brave_dir/Local State"

      mkdir -p "$brave_dir/Default"

      ensure_json_file() {
        local path="$1"

        if [ ! -s "$path" ] || ! ${pkgs.jq}/bin/jq -e . "$path" >/dev/null 2>&1; then
          printf '{}\n' > "$path"
        fi
      }

      ensure_json_file "$prefs"
      ensure_json_file "$local_state"

      tmp_prefs="$(${pkgs.coreutils}/bin/mktemp)"
      ${pkgs.jq}/bin/jq '
        .brave.tabs.vertical_tabs_enabled = true
        | .brave.enable_media_router_on_restart = false
        | .brave.web_discovery_enabled = false
        | .browser.show_home_button = false
        | .browser.custom_chrome_frame = true
        | .browser.theme.color_scheme2 = 2
      ' "$prefs" > "$tmp_prefs"
      mv "$tmp_prefs" "$prefs"

      tmp_local_state="$(${pkgs.coreutils}/bin/mktemp)"
      ${pkgs.jq}/bin/jq '
        .brave.vertical_tabs.enabled = true
      ' "$local_state" > "$tmp_local_state"
      mv "$tmp_local_state" "$local_state"
    '';
  };
}
