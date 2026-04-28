{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.browser;
  minimalBrowserChrome = ''
    :root {
      color-scheme: dark !important;
      --zen-base: #0b0d10;
      --zen-surface: #111419;
      --zen-elevated: #171b21;
      --zen-muted: #98a2b3;
      --zen-border: rgba(226, 232, 240, 0.14);
      --zen-border-strong: rgba(226, 232, 240, 0.24);
      --zen-accent: #d7ba8a;
      --zen-fg: #edf2f7;
      --tab-min-height: 34px !important;
      --toolbarbutton-border-radius: 12px !important;
      --arrowpanel-border-radius: 16px !important;
      --lwt-accent-color: var(--zen-base) !important;
      --lwt-text-color: var(--zen-fg) !important;
      --toolbar-bgcolor: transparent !important;
      --toolbar-color: var(--zen-fg) !important;
      --toolbar-field-background-color: rgba(23, 27, 33, 0.92) !important;
      --toolbar-field-border-color: var(--zen-border) !important;
      --toolbar-field-color: var(--zen-fg) !important;
      --tab-selected-bgcolor: rgba(23, 27, 33, 0.98) !important;
      --tab-selected-textcolor: var(--zen-fg) !important;
      --tabpanel-background-color: var(--zen-base) !important;
    }

    #navigator-toolbox {
      background: linear-gradient(180deg, #0b0d10 0%, #111419 100%) !important;
      border-bottom: 0 !important;
      padding: 6px 10px 4px !important;
    }

    #TabsToolbar,
    #nav-bar,
    #PersonalToolbar,
    #sidebar-box {
      background: transparent !important;
    }

    #nav-bar {
      border: 1px solid var(--zen-border) !important;
      border-radius: 16px !important;
      margin-top: 6px !important;
      padding: 4px 8px !important;
    }

    #urlbar-background,
    .searchbar-textbox {
      background: rgba(23, 27, 33, 0.92) !important;
      border: 1px solid var(--zen-border) !important;
      border-radius: 14px !important;
    }

    #urlbar[open] > #urlbar-background,
    #urlbar[focused] > #urlbar-background {
      border-color: var(--zen-border-strong) !important;
      box-shadow: 0 0 0 1px rgba(215, 186, 138, 0.18) !important;
    }

    .tabbrowser-tab {
      padding-inline: 4px !important;
    }

    .tabbrowser-tab .tab-background {
      border: 1px solid transparent !important;
      border-radius: 12px !important;
      box-shadow: none !important;
      margin-block: 3px !important;
    }

    .tabbrowser-tab[selected="true"] .tab-background {
      background: linear-gradient(180deg, rgba(23, 27, 33, 0.98) 0%, rgba(30, 36, 44, 0.96) 100%) !important;
      border-color: var(--zen-border-strong) !important;
    }

    .tabbrowser-tab:hover .tab-background {
      background: rgba(23, 27, 33, 0.82) !important;
    }

    .tab-content,
    #urlbar-input,
    #searchbar,
    .toolbarbutton-1,
    .tabbrowser-tab {
      color: var(--zen-fg) !important;
    }

    .tab-label {
      font-weight: 500 !important;
    }

    #tabs-newtab-button,
    #new-tab-button,
    #alltabs-button,
    .toolbarbutton-1 {
      fill: var(--zen-accent) !important;
    }

    .toolbarbutton-1:hover {
      background: rgba(215, 186, 138, 0.10) !important;
    }

    #PersonalToolbar {
      min-height: 0 !important;
    }

    .menupopup-arrowscrollbox,
    panel[type="arrow"] {
      background: rgba(17, 20, 25, 0.98) !important;
      color: var(--zen-fg) !important;
    }
  '';
  zenUserJs = pkgs.writeText "zen-minimal-user.js" ''
    user_pref("app.shield.optoutstudies.enabled", false);
    user_pref("browser.compactmode.show", true);
    user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
    user_pref("browser.newtabpage.activity-stream.feeds.system.topstories", false);
    user_pref("browser.newtabpage.activity-stream.showSponsored", false);
    user_pref("browser.newtabpage.activity-stream.system.showSponsored", false);
    user_pref("browser.toolbars.bookmarks.visibility", "never");
    user_pref("browser.uidensity", 1);
    user_pref("browser.urlbar.quicksuggest.enabled", false);
    user_pref("browser.urlbar.quicksuggest.sponsored", false);
    user_pref("extensions.pocket.enabled", false);
    user_pref("signon.rememberSignons", true);
    user_pref("svg.context-properties.content.enabled", true);
    user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
  '';
  zenUserChrome = pkgs.writeText "zen-minimal-userChrome.css" minimalBrowserChrome;
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
        OfferToSaveLogins = true;
      };
      profiles.asura = {
        id = 0;
        isDefault = true;
        name = "asura";
        search = {
          force = true;
          default = "ddg";
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
          "signon.rememberSignons" = true;
          "svg.context-properties.content.enabled" = true;
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        };
        userChrome = minimalBrowserChrome;
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

    home.activation.configureZenProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -euo pipefail
      zen_root="$HOME/.config/zen"

      if [ ! -d "$zen_root" ]; then
        exit 0
      fi

      find "$zen_root" -mindepth 1 -maxdepth 1 -type d ! -name 'Profile Groups' -print0 \
        | while IFS= read -r -d $'\0' profile; do
            ${pkgs.coreutils}/bin/install -Dm644 ${zenUserJs} "$profile/user.js"
            ${pkgs.coreutils}/bin/install -Dm644 ${zenUserChrome} "$profile/chrome/userChrome.css"
          done
    '';
  };
}
