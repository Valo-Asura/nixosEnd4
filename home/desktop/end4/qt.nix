{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.programs.illogical-impulse;
  pythonEnv = cfg.internal.pythonEnv;

  # Upstream quickshell still references the deprecated xorg.libxcb alias.
  # Override that input argument locally so evaluation stays warning-free.
  qsPackage = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
    xorg = pkgs.xorg // {
      libxcb = pkgs.libxcb;
    };
  };

  qtImports = [
    pkgs.kdePackages.qtbase
    pkgs.kdePackages.qtdeclarative
    pkgs.kdePackages.qtsvg
    pkgs.kdePackages.qtwayland
    pkgs.kdePackages.qt5compat
    pkgs.kdePackages.qtimageformats
    pkgs.kdePackages.qtmultimedia
    pkgs.kdePackages.qtpositioning
    pkgs.kdePackages.qtsensors
    pkgs.kdePackages.qtquicktimeline
    pkgs.kdePackages.qttools
    pkgs.kdePackages.qttranslations
    pkgs.kdePackages.qtvirtualkeyboard
    pkgs.kdePackages.qtwebsockets
    pkgs.kdePackages.syntax-highlighting
    pkgs.kdePackages.kirigami.unwrapped
  ];

  customPkgs = import "${inputs.illogical-flake.outPath}/pkgs" { inherit pkgs; };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.writeShellScriptBin "qs" ''
        export QT_PLUGIN_PATH="${lib.makeSearchPath "lib/qt-6/plugins" qtImports}:${lib.makeSearchPath "lib/qt6/plugins" qtImports}:${lib.makeSearchPath "lib/plugins" qtImports}"
        export QML2_IMPORT_PATH="${lib.makeSearchPath "lib/qt-6/qml" qtImports}"

        export XDG_DATA_DIRS="${
          lib.makeSearchPath "share" [
            pkgs.adwaita-icon-theme
            pkgs.hicolor-icon-theme
            pkgs.papirus-icon-theme
            customPkgs.illogical-impulse-oneui4-icons
            pkgs.gnome-icon-theme
            pkgs.kdePackages.breeze-icons
            pkgs.lxqt.pavucontrol-qt
            pkgs.pavucontrol
          ]
        }:$HOME/.nix-profile/share:$HOME/.local/share:/etc/profiles/per-user/$USER/share:/run/current-system/sw/share:/usr/share:$XDG_DATA_DIRS"

        export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
        export QT_QPA_PLATFORMTHEME=gtk3
        export QSG_RENDER_LOOP="''${QSG_RENDER_LOOP:-basic}"

        exec ${qsPackage}/bin/qs "$@"
      '')
    ]
    ++ qtImports
    ++ [
      pkgs.qt6Packages.qt6ct
      pythonEnv
    ];
  };
}
