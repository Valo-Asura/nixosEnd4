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
      google-chrome
    ];

    programs.firefox = {
      enable = true;
      policies = {
        DisableTelemetry = true;
        DisablePocket = true;
        DisplayBookmarksToolbar = "never";
        DontCheckDefaultBrowser = true;
        NoDefaultBookmarks = true;
        OfferToSaveLogins = false;
      };
      profiles.asura = {
        id = 0;
        isDefault = true;
        name = "asura";
        search = {
          force = true;
          default = "DuckDuckGo";
        };
        settings = {
          "app.shield.optoutstudies.enabled" = false;
          "browser.compactmode.show" = true;
          "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
          "browser.newtabpage.activity-stream.feeds.system.topstories" = false;
          "browser.newtabpage.activity-stream.showSponsored" = false;
          "browser.newtabpage.activity-stream.system.showSponsored" = false;
          "browser.tabs.inTitlebar" = 1;
          "browser.theme.toolbar-theme" = 0;
          "browser.toolbars.bookmarks.visibility" = "never";
          "browser.uidensity" = 1;
          "browser.urlbar.quicksuggest.enabled" = false;
          "browser.urlbar.quicksuggest.sponsored" = false;
          "extensions.pocket.enabled" = false;
          "svg.context-properties.content.enabled" = true;
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        };
        userChrome = ''
          :root {
            color-scheme: dark !important;
            --rose-base: #120b10;
            --rose-surface: #1b1018;
            --rose-elevated: #2a1620;
            --rose-border: rgba(255, 127, 151, 0.22);
            --rose-border-strong: rgba(255, 127, 151, 0.38);
            --rose-accent: #ff6b84;
            --rose-accent-strong: #ff4d6d;
            --rose-fg: #f7d7dd;
            --tab-min-height: 38px !important;
            --toolbarbutton-border-radius: 12px !important;
            --arrowpanel-border-radius: 16px !important;
            --lwt-accent-color: var(--rose-base) !important;
            --lwt-text-color: var(--rose-fg) !important;
            --toolbar-bgcolor: transparent !important;
            --toolbar-color: var(--rose-fg) !important;
            --toolbar-field-background-color: rgba(42, 22, 32, 0.9) !important;
            --toolbar-field-border-color: var(--rose-border) !important;
            --toolbar-field-color: var(--rose-fg) !important;
            --tab-selected-bgcolor: rgba(42, 22, 32, 0.96) !important;
            --tab-selected-textcolor: var(--rose-fg) !important;
            --tabpanel-background-color: var(--rose-base) !important;
          }

          #navigator-toolbox {
            background: linear-gradient(180deg, #120b10 0%, #1b1018 100%) !important;
            border-bottom: 0 !important;
          }

          #TabsToolbar,
          #nav-bar,
          #PersonalToolbar,
          #sidebar-box {
            background: transparent !important;
          }

          #urlbar-background,
          .searchbar-textbox {
            background: rgba(42, 22, 32, 0.9) !important;
            border: 1px solid var(--rose-border) !important;
            border-radius: 14px !important;
          }

          #urlbar[open] > #urlbar-background,
          #urlbar[focused] > #urlbar-background {
            border-color: var(--rose-border-strong) !important;
            box-shadow: 0 0 0 1px rgba(255, 107, 132, 0.2) !important;
          }

          .tabbrowser-tab[selected="true"] .tab-background {
            background: linear-gradient(180deg, rgba(42, 22, 32, 0.98) 0%, rgba(58, 28, 42, 0.96) 100%) !important;
            border: 1px solid var(--rose-border-strong) !important;
            box-shadow: inset 0 1px 0 rgba(255, 107, 132, 0.16) !important;
          }

          .tabbrowser-tab:hover .tab-background {
            background: rgba(42, 22, 32, 0.82) !important;
          }

          .tab-content,
          #urlbar-input,
          #searchbar,
          .toolbarbutton-1 {
            color: var(--rose-fg) !important;
          }

          #tabs-newtab-button,
          #new-tab-button,
          #alltabs-button,
          .toolbarbutton-1 {
            fill: var(--rose-accent) !important;
          }

          .toolbarbutton-1:hover {
            background: rgba(255, 107, 132, 0.12) !important;
          }

          .menupopup-arrowscrollbox,
          panel[type="arrow"] {
            background: rgba(27, 16, 24, 0.98) !important;
            color: var(--rose-fg) !important;
          }
        '';
      };
    };

    home.activation.configureChromeProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -euo pipefail
      chrome_dir="$HOME/.config/google-chrome"
      prefs="$chrome_dir/Default/Preferences"
      local_state="$chrome_dir/Local State"

      mkdir -p "$chrome_dir/Default"

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
        .browser.show_home_button = false
        | .browser.custom_chrome_frame = true
        | .browser.theme.color_scheme = 2
        | .bookmark_bar.show_on_all_tabs = false
        | .extensions.toolbar_menu.enabled = true
      ' "$prefs" > "$tmp_prefs"
      mv "$tmp_prefs" "$prefs"

      tmp_local_state="$(${pkgs.coreutils}/bin/mktemp)"
      ${pkgs.jq}/bin/jq '
        .browser.enabled_labs_experiments = []
      ' "$local_state" > "$tmp_local_state"
      mv "$tmp_local_state" "$local_state"
    '';
  };
}
