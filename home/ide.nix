{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.ide;
  vscodeExtensions = with pkgs.vscode-extensions; [
    bbenoist.nix
    github.github-vscode-theme
    jnoortheen.nix-ide
    mkhl.direnv
    ms-python.python
    ms-toolsai.jupyter
    pkief.material-icon-theme
    rust-lang.rust-analyzer
  ];
  ideExtensionIds = [
    "bbenoist.nix"
    "github.github-vscode-theme"
    "jnoortheen.nix-ide"
    "mkhl.direnv"
    "ms-python.python"
    "ms-toolsai.jupyter"
    "pkief.material-icon-theme"
    "rust-lang.rust-analyzer"
  ];
in
{
  options.modules.ide = {
    enable = lib.mkEnableOption "VS Code and related IDE tooling";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      code-cursor
      kiro
      antigravity
    ];

    # Keep VS Code settings mutable because programs.vscode emits this as a
    # home.file entry and the activation hook merges nix-specific settings
    # into the live file for multiple IDEs.
    home.file."${config.xdg.configHome}/Code/User/settings.json".enable = lib.mkForce false;

    programs.vscode = {
      enable = true;
      package = pkgs.vscode;
      profiles.default = {
        extensions = vscodeExtensions;
        enableUpdateCheck = false;
        enableExtensionUpdateCheck = false;
      };
    };

    home.activation.installOtherIdeExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -euo pipefail
      state_dir="$HOME/.local/state/nixos-ide"
      marker="$state_dir/extensions-v2"
      wanted='${lib.concatStringsSep "," ideExtensionIds}'

      mkdir -p "$state_dir"
      if [ ! -f "$marker" ] || [ "$(${pkgs.coreutils}/bin/cat "$marker" 2>/dev/null || true)" != "$wanted" ]; then
        install_for() {
          local bin="$1"
          [ -x "$bin" ] || return 0

          local installed
          installed="$("$bin" --list-extensions 2>/dev/null || true)"

          for ext in ${lib.concatStringsSep " " ideExtensionIds}; do
            if ! printf '%s\n' "$installed" | ${pkgs.gnugrep}/bin/grep -Fxq "$ext"; then
              "$bin" --install-extension "$ext" --force >/dev/null 2>&1 || true
            fi
          done
        }

        install_for "${pkgs.code-cursor}/bin/cursor"
        install_for "${pkgs.kiro}/bin/kiro"
        install_for "${pkgs.antigravity}/bin/antigravity"

        ${pkgs.coreutils}/bin/printf '%s' "$wanted" > "$marker"
      fi
    '';

    home.activation.configureAllIdeNixSupport = lib.hm.dag.entryAfter [ "installOtherIdeExtensions" ] ''
      set -euo pipefail
      state_dir="$HOME/.local/state/nixos-ide"
      marker="$state_dir/nix-settings-v2"
      wanted="nil=${pkgs.nil}/bin/nil;nixfmt=${pkgs.nixfmt}/bin/nixfmt;theme=GitHub Dark Dimmed"

      mkdir -p "$state_dir"
      settings_need_merge() {
        local app="$1"
        local settings="$HOME/.config/$app/User/settings.json"

        if [ ! -s "$settings" ] || ! ${pkgs.jq}/bin/jq -e . "$settings" >/dev/null 2>&1; then
          return 0
        fi

        ${pkgs.jq}/bin/jq -e \
          --arg nil "${pkgs.nil}/bin/nil" \
          --arg nixfmt "${pkgs.nixfmt}/bin/nixfmt" \
          '
            ."nix.enableLanguageServer" == true and
            ."nix.serverPath" == $nil and
            ."nix.formatterPath" == $nixfmt and
            .["[nix]"]["editor.defaultFormatter"] == "jnoortheen.nix-ide" and
            .["[nix]"]["editor.formatOnSave"] == true and
            ."workbench.colorTheme" == "GitHub Dark Dimmed" and
            ."workbench.iconTheme" == "material-icon-theme" and
            ."window.commandCenter" == false and
            ."telemetry.telemetryLevel" == "off" and
            ."update.mode" == "none"
          ' \
          "$settings" >/dev/null 2>&1 || return 0

        return 1
      }

      merge_settings() {
        local app="$1"
        local cfg_dir="$HOME/.config/$app/User"
        local settings="$cfg_dir/settings.json"
        local tmp

        mkdir -p "$cfg_dir"
        if [ ! -s "$settings" ] || ! ${pkgs.jq}/bin/jq -e . "$settings" >/dev/null 2>&1; then
          echo '{}' > "$settings"
        fi

        tmp="$(${pkgs.coreutils}/bin/mktemp)"
        ${pkgs.jq}/bin/jq \
          --arg nil "${pkgs.nil}/bin/nil" \
          --arg nixfmt "${pkgs.nixfmt}/bin/nixfmt" \
          '. + {
            "nix.enableLanguageServer": true,
            "nix.serverPath": $nil,
            "nix.formatterPath": $nixfmt,
            "workbench.colorTheme": "GitHub Dark Dimmed",
            "workbench.iconTheme": "material-icon-theme",
            "workbench.list.smoothScrolling": true,
            "workbench.editor.smoothScrolling": true,
            "window.commandCenter": false,
            "window.titleBarStyle": "custom",
            "editor.fontLigatures": true,
            "editor.cursorSmoothCaretAnimation": "on",
            "editor.smoothScrolling": true,
            "telemetry.telemetryLevel": "off",
            "update.mode": "none",
            "extensions.autoCheckUpdates": false,
            "extensions.autoUpdate": false,
            "workbench.enableExperiments": false,
            "workbench.tips.enabled": false
          }
          | .["[nix]"] = ((.["[nix]"] // {}) + {
            "editor.defaultFormatter": "jnoortheen.nix-ide",
            "editor.formatOnSave": true
          })' \
          "$settings" > "$tmp"

        mv "$tmp" "$settings"
      }

      needs_update=0
      if [ ! -f "$marker" ] || [ "$(${pkgs.coreutils}/bin/cat "$marker" 2>/dev/null || true)" != "$wanted" ]; then
        needs_update=1
      else
        for app in Code Cursor Kiro Antigravity; do
          if settings_need_merge "$app"; then
            needs_update=1
            break
          fi
        done
      fi

      if [ "$needs_update" -eq 1 ]; then
        merge_settings "Code"
        merge_settings "Cursor"
        merge_settings "Kiro"
        merge_settings "Antigravity"

        ${pkgs.coreutils}/bin/printf '%s' "$wanted" > "$marker"
      fi
    '';
  };
}
