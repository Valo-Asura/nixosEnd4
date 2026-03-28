{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.illogical-impulse;

  customPkgs = import "${inputs.illogical-flake.outPath}/pkgs" { inherit pkgs; };

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.build
    ps.cffi
    ps.click
    ps."dbus-python"
    ps."kde-material-you-colors"
    ps.libsass
    ps.loguru
    ps."material-color-utilities"
    ps.materialyoucolor
    ps.numpy
    ps.pillow
    ps.psutil
    ps.pycairo
    ps.pygobject3
    ps.pywayland
    ps.setproctitle
    ps."setuptools-scm"
    ps.tqdm
    ps.wheel
    ps."pyproject-hooks"
    ps.opencv4
  ]);
in
{
  options.programs.illogical-impulse.internal.pythonEnv = lib.mkOption {
    type = lib.types.package;
    internal = true;
    default = pythonEnv;
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        cava
        lxqt.pavucontrol-qt
        wireplumber
        libdbusmenu-gtk3
        playerctl
        brightnessctl
        ddcutil
        axel
        bc
        cliphist
        curl
        rsync
        wget
        libqalculate
        ripgrep
        jq

        foot
        fuzzel
        matugen
        mpv
        mpvpaper
        swappy
        wf-recorder
        hyprshot
        wlogout

        xdg-user-dirs
        tesseract
        slurp
        upower
        wtype
        ydotool
        glib
        swww
        translate-shell
        hyprpicker
        imagemagick
        ffmpeg
        songrec
        pulseaudio
        libnotify
        grim

        hyprlock
        hypridle
        hyprsunset
        wayland-protocols
        wl-clipboard

        libsoup_3
        libportal-gtk4
        gobject-introspection
        sassc

        adw-gtk3
        customPkgs.illogical-impulse-oneui4-icons
        papirus-icon-theme
        adwaita-icon-theme
        hicolor-icon-theme
        gnome-icon-theme
        kdePackages.breeze-icons

        pythonEnv
        eza

        gnome-keyring
        kdePackages.polkit-kde-agent-1
        kdePackages.kdialog
        kdePackages.kirigami

        libsForQt5.qtgraphicaleffects
        libsForQt5.qtsvg
        libsecret
      ]
      ++ lib.optionals cfg.internal.features.kde [
        kdePackages.bluedevil
        kdePackages.plasma-nm
        kdePackages.plasma-workspace
        kdePackages.kde-cli-tools
      ]
      ++ lib.optionals cfg.dotfiles.fish.enable [
        fish
      ]
      ++ lib.optionals cfg.dotfiles.kitty.enable [
        kitty
      ]
      ++ lib.optionals cfg.dotfiles.starship.enable [
        starship
      ];
  };
}
