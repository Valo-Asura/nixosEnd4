{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.mimeapps;
  seededMimeDefaults = [
    {
      desktop = "nemo.desktop";
      mimes = [
        "inode/directory"
        "application/x-gnome-saved-search"
      ];
    }
    {
      desktop = "zen.desktop";
      mimes = [
        "text/html"
        "application/xhtml+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
        "x-scheme-handler/about"
        "x-scheme-handler/unknown"
      ];
    }
    {
      desktop = "org.gnome.TextEditor.desktop";
      mimes = [
        "text/plain"
      ];
    }
    {
      desktop = "org.gnome.Loupe.desktop";
      mimes = [
        "image/png"
        "image/jpeg"
        "image/webp"
        "image/gif"
      ];
    }
    {
      desktop = "org.gnome.Papers.desktop";
      mimes = [
        "application/pdf"
      ];
    }
    {
      desktop = "org.gnome.FileRoller.desktop";
      mimes = [
        "application/zip"
        "application/x-7z-compressed"
        "application/x-rar"
        "application/x-tar"
        "application/gzip"
      ];
    }
    {
      desktop = "vlc.desktop";
      mimes = [
        "video/mp4"
        "video/webm"
        "video/x-matroska"
        "audio/mpeg"
        "audio/flac"
        "audio/x-wav"
      ];
    }
  ];
  addedAssociationLines = lib.concatMapStringsSep "\n" (
    entry:
    lib.concatMapStringsSep "\n" (mime: "${mime}=${entry.desktop};") entry.mimes
  ) seededMimeDefaults;
  defaultApplicationLines = lib.concatMapStringsSep "\n" (
    entry:
    lib.concatMapStringsSep "\n" (mime: "${mime}=${entry.desktop};") entry.mimes
  ) seededMimeDefaults;
  mimeAppsListText = ''
    [Added Associations]
    ${addedAssociationLines}

    [Default Applications]
    ${defaultApplicationLines}

    [Removed Associations]
  '';
in
{
  options.modules.mimeapps = {
    enable = lib.mkEnableOption "writable MIME defaults and file-manager helpers";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      xdg-utils
      gnome-text-editor
      loupe
      papers
      file-roller
    ];

    # Keep MIME ownership declarative, but do not let Home Manager turn the live
    # config files into read-only store links. Nemo needs writable files for
    # "Open With" and "Set as Default" to work during the session.
    xdg.configFile."mimeapps.list".enable = lib.mkForce false;
    xdg.dataFile."applications/mimeapps.list".enable = lib.mkForce false;

    home.activation.configureMimeApps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -euo pipefail

      export XDG_CONFIG_HOME="$HOME/.config"
      export XDG_DATA_HOME="$HOME/.local/share"

      ensure_regular_mime_file() {
        local path="$1"
        local dir target tmp

        dir="$(${pkgs.coreutils}/bin/dirname "$path")"
        mkdir -p "$dir"

        if [ -L "$path" ]; then
          target="$(${pkgs.coreutils}/bin/readlink "$path" || true)"
          case "$target" in
            /nix/store/*)
              tmp="$(${pkgs.coreutils}/bin/mktemp)"
              if ! ${pkgs.coreutils}/bin/cp "$path" "$tmp" 2>/dev/null; then
                : > "$tmp"
              fi
              ${pkgs.coreutils}/bin/rm -f "$path"
              ${pkgs.coreutils}/bin/mv "$tmp" "$path"
              ;;
          esac
        fi

        if [ ! -e "$path" ]; then
          : > "$path"
        fi
      }

      write_mime_file() {
        local path="$1"
        ${pkgs.coreutils}/bin/printf '%s' ${lib.escapeShellArg mimeAppsListText} > "$path"
      }

      ensure_regular_mime_file "$XDG_CONFIG_HOME/mimeapps.list"
      ensure_regular_mime_file "$XDG_DATA_HOME/applications/mimeapps.list"

      write_mime_file "$XDG_CONFIG_HOME/mimeapps.list"
      write_mime_file "$XDG_DATA_HOME/applications/mimeapps.list"
    '';
  };
}
