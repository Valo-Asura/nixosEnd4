{
  config,
  lib,
  pkgs,
  inputs,
  hostname,
  ...
}:

let
  startHyprland = pkgs.writeShellScriptBin "start-hyprland" ''
    export XDG_CURRENT_DESKTOP=Hyprland
    export XDG_SESSION_TYPE=wayland
    export XDG_SESSION_DESKTOP=Hyprland

    # Recommended for some apps in Wayland
    export MOZ_ENABLE_WAYLAND=1
    export _JAVA_AWT_WM_NONREPARENTING=1
    export QT_QPA_PLATFORM=wayland
    export SDL_VIDEODRIVER=wayland
    export CLUTTER_BACKEND=wayland

    exec ${config.programs.hyprland.package}/bin/Hyprland
  '';
in
{
  imports = [
    ../../hardware-configuration.nix
    ../../modules/default.nix
  ];

  nixpkgs.config.allowUnfree = true;

  modules = {
    boot.enable = true;

    performance = {
      enable = true;
      profile = "balanced";
      nbfcProfile = "Colorful X15 AT 22";
    };

    nvidia = {
      enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };

    portal.enable = true;

    ollama = {
      enable = true;
      preloadModel = false;
      defaultModel = "qwen2.5:3b";
      gpuOverheadBytes = 536870912;  # 512 MB overhead (was 1 GB; qwen2.5:3b is smaller)
      keepAlive = "2m";
      contextLength = 4096;  # Fits fully in 4 GB VRAM with qwen2.5:3b
      flashAttention = true;
      maxLoadedModels = 1;
      guiEnable = false;
      guiHost = "127.0.0.1";
      guiPort = 8080;
      guiOpenFirewall = false;
    };
  };

  networking.hostName = lib.mkDefault hostname;
  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "systemd-resolved";
  services.resolved.enable = true;
  systemd.services.systemd-rfkill.enable = lib.mkForce true;
  systemd.sockets.systemd-rfkill.enable = lib.mkForce true;
  # Reduce boot delays caused by waiting for full network-online.
  systemd.services.NetworkManager-wait-online.enable = false;
  systemd.settings.Manager.ShowStatus = "no";

  boot = {
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "loglevel=3"
      "rd.systemd.show_status=auto"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "nvidia.NVreg_TemporaryFilePath=/var/tmp"
    ];
  };

  time.timeZone = "Asia/Kolkata";
  # glibc 2.42 expects `en_IN/UTF-8` (without `.UTF-8` in the locale name)
  # when composing generated locales.
  i18n.defaultLocale = "en_IN";

  console.keyMap = "us";

  users.users.asura = {
    isNormalUser = true;
    description = "asura";
    hashedPassword = "$y$j9T$2zpKRiUR37bkTPqry0Y.V1$JmiVRAgJ7.0zeH5EvelVOwlXGUsTw23tcdcoHkDfr.B";
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
      "render"
      "input"
    ];
  };

  programs.zsh.enable = true;

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --cmd ${startHyprland}/bin/start-hyprland --remember --remember-user-session --asterisks --greeting asura --time";
      user = "greeter";
    };
  };

  # Keep browser and desktop secrets unlocked across greetd logins.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  services.getty = {
    greetingLine = "";
    helpLine = "";
  };

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage =
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  # Required by illogical-flake (QtPositioning / geolocation)
  services.geoclue2.enable = true;

  fonts.packages = with pkgs; [
    rubik
    nerd-fonts.ubuntu
    nerd-fonts.jetbrains-mono
  ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General = {
      FastConnectable = true;
      JustWorksRepairing = "always";
      Privacy = "device";
    };
  };
  services.blueman.enable = true;
  services.upower.enable = true;

  security.polkit.enable = true;

  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };
    };
  };

  # Wrapper script to ensure Hyprland starts with the right environment.
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    vim
    pciutils
    wsdd
    startHyprland
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    max-jobs = "auto";
    cores = 0;
    min-free = 1073741824;
    max-free = 5368709120;
    keep-outputs = true;
    keep-derivations = true;
  };

  nix.gc = {
    automatic = true;
    dates = "Sun 04:30";
    randomizedDelaySec = "45m";
    options = "--delete-older-than 7d";
    # Prevent catch-up GC runs right after login/boot, which can look like UI lag.
    persistent = false;
  };

  nix.optimise = {
    automatic = true;
    dates = [ "Sun 05:30" ];
    randomizedDelaySec = "45m";
  };

  system.stateVersion = "25.11";
}
