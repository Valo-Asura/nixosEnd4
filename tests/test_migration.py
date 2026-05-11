from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (REPO / path).read_text()


def all_text(paths):
    return "\n".join(read(path) for path in paths)


def nix_files():
    return sorted(
        str(path.relative_to(REPO))
        for path in REPO.rglob("*.nix")
        if ".git" not in path.parts
        and "home/desktop/quickshell/profiles" not in str(path.relative_to(REPO))
    )


def test_flake_keeps_only_package_level_inputs():
    flake = read("flake.nix")
    assert 'nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";' in flake
    assert 'url = "github:nix-community/home-manager";' in flake
    assert 'url = "github:hyprwm/Hyprland/v0.54.0";' in flake
    assert 'url = "git+https://git.outfoxxed.me/quickshell/quickshell";' in flake
    assert 'url = "github:InioX/matugen";' in flake
    assert 'url = "github:nix-community/stylix";' in flake
    assert 'url = "github:youwen5/zen-browser-flake";' in flake
    assert "illogical-flake" not in flake
    assert "ilyamiro-nixos-configuration" not in flake
    assert "/home/asura/Downloads" not in flake
    assert "sharedModules" not in flake


def test_grouped_module_structure_is_the_system_entrypoint():
    modules_default = read("modules/default.nix")
    assert "./core" in modules_default
    assert "./hardware/x15xs" in modules_default
    assert "./performance" in modules_default
    assert "./desktop" in modules_default
    assert "./services" in modules_default
    assert (REPO / "modules/core/boot.nix").exists()
    assert (REPO / "modules/hardware/x15xs/hardware-configuration.nix").exists()
    assert (REPO / "modules/performance/default.nix").exists()
    assert not (REPO / "modules/performance-enhanced.nix").exists()


def test_host_uses_hardware_inventory_and_balanced_fast_default():
    host = read("hosts/x15xs/default.nix")
    assert "hardware.x15xs.enable = true;" in host
    assert 'profile = "balanced-fast";' in host
    assert "config.modules.hardware.x15xs.nbfcProfile" in host
    assert "config.modules.hardware.x15xs.graphics.intelBusId" in host
    assert "config.modules.hardware.x15xs.graphics.nvidiaBusId" in host
    assert "performanceEnhanced" not in host


def test_performance_module_is_single_profile_based_module():
    performance = read("modules/performance/default.nix")
    assert '"balanced-fast"' in performance
    assert '"max"' in performance
    assert '"cool"' in performance
    assert 'default = "balanced-fast";' in performance
    assert "zramSwap" in performance
    assert '"net.ipv4.tcp_congestion_control" = "bbr";' in performance
    assert 'DISK_IOSCHED = "kyber";' in performance
    assert '"mitigations=off"' in performance
    assert "lib.optionals isMax" in performance
    default_block = performance.split("kernelParams = [", 1)[1].split("]", 1)[0]
    assert "mitigations=off" not in default_block
    assert "spectre_v2=off" not in performance
    assert "nopti" not in performance
    assert "nohz_full" not in performance
    assert "performanceEnhanced" not in performance


def test_nbfc_selector_model_split_is_preserved():
    performance = read("modules/performance/default.nix")
    monitor = read("modules/hardware/x15xs/hardware-monitor.nix")
    assert '"nbfc/configs/${cfg.nbfcProfile}.json".text = nbfcModelConfig;' in performance
    assert '"nbfc/nbfc.json".text = nbfcServiceConfig;' in performance
    assert "SelectedConfigId" in performance
    assert ".SelectedConfigId // empty" in monitor


def test_quickshell_uses_vendored_profiles_only():
    quickshell = read("home/desktop/quickshell/default.nix")
    weather = read("home/desktop/quickshell/profiles/ilyamiro/scripts/quickshell/calendar/weather.sh")
    settings_watcher = read("home/desktop/quickshell/profiles/ilyamiro/scripts/settings_watcher.sh")
    assert "./profiles/end4/ii" in quickshell
    assert "./profiles/ilyamiro/scripts" in quickshell
    assert "x15-quickshell-config" in quickshell
    assert "quickshell-switch" in quickshell
    assert "quickshell-session" in quickshell
    assert "boot|start-default" in quickshell
    assert "exec ${qsCommand}/bin/qs -c ii" in quickshell
    assert "exec ${qsCommand}/bin/qs -c ii -p" not in quickshell
    assert 'xdg.configFile."quickshell" = {' in quickshell
    assert 'xdg.configFile."quickshell/ii"' not in quickshell
    assert "inputs.ilyamiro" not in quickshell
    assert "/home/asura/Downloads" not in quickshell
    assert (REPO / "home/desktop/quickshell/profiles/end4/ii/shell.qml").exists()
    assert (REPO / "home/desktop/quickshell/profiles/ilyamiro/scripts/quickshell/Main.qml").exists()
    assert "OPENMETEO_LATITUDE" in quickshell
    assert "get_open_meteo_data" in weather
    assert 'WEATHER_SCRIPT="$HOME/.config/hypr/scripts/quickshell/calendar/weather.sh"' in settings_watcher


def test_hyprland_uses_local_assets_and_fixed_super_binds():
    hyprland = read("home/desktop/hyprland.nix")
    hypr_keybinds_asset = read("home/desktop/hypr/assets/hyprland/keybinds.conf")
    assert "inputs.illogical-flake" not in hyprland
    assert "./hypr/assets/hyprland/general.conf" in hyprland
    assert "./hypr/assets/hyprland/execs.conf" in hyprland
    assert "./hypr/assets/hyprland/rules.conf" in hyprland
    assert 'xdg.configFile."hypr/hyprland.conf"' in hyprland
    assert "hyprRootConfig" in hyprland
    assert "quickshell-session-boot" in hyprland
    assert "quickshell-service-start" in hyprland
    assert "quickshell-super-interrupt" in hyprland
    assert "resolveQsRuntime" in hyprland
    assert "bind = $mainMod, Q, exec, ${superDispatch}/bin/super-dispatch killactive" in hyprland
    assert "submap = global" not in hyprland
    assert "submap = reset" in hyprland
    assert "submap global" not in hyprland
    assert "submap reset" in hyprland
    assert "bind = $mainMod, V, exec, ${superRun}/bin/super-run ${clipboardPicker}/bin/clipboard" in hyprland
    assert "bind = $shiftMod, V, exec, ${superDispatch}/bin/super-dispatch togglefloating" in hyprland
    assert "bind = $mainMod, V, exec, ${superDispatch}/bin/super-dispatch togglefloating" not in hyprland
    assert "bindr = $mainMod, Super_L, exec, ${superReleaseLauncher}/bin/super-release-launcher" in hyprland
    assert "bindr = $mainMod, Super_R, exec, ${superReleaseLauncher}/bin/super-release-launcher" in hyprland
    assert "bindid = Super, Super_L, Toggle search, global, quickshell:searchToggleRelease" not in hyprland
    assert "bindid = Super, Super_R, Toggle search, global, quickshell:searchToggleRelease" not in hyprland
    assert "binditn = Super, catchall, global, quickshell:searchToggleReleaseInterrupt" not in hyprland
    assert "bind = $mainMod, D, exec, ${superRun}/bin/super-run ${searchLauncher}/bin/search-launcher" in hyprland
    assert "bind = $mainMod, Space, exec, ${superRun}/bin/super-run ${searchLauncher}/bin/search-launcher" in hyprland
    assert "bind = Super, Super_L, exec, search-launcher-super" not in hyprland
    assert "bind = Super, Super_R, exec, search-launcher-super" not in hyprland
    assert "workspace_swipe_create_new = true" in hyprland
    assert "exec-once = ${quickshellServiceStart}/bin/quickshell-service-start &" in hyprland
    assert "quickshell-session-boot starting" in hyprland
    assert "x15-quickshell.service restarted" in hyprland
    assert "${searchLauncher}/bin/search-launcher" in hyprland
    assert "/run/wrappers/bin:/run/current-system/sw/bin" in hyprland

    hypr_env = read("home/desktop/hypr/assets/hyprland/env.conf")
    assert "/run/wrappers/bin:/run/current-system/sw/bin" in hypr_env
    assert "submap = global" not in hypr_keybinds_asset
    assert "submap global" not in hypr_keybinds_asset
    assert "submap = reset" in hypr_keybinds_asset

    ilyamiro_main = read("home/desktop/quickshell/profiles/ilyamiro/scripts/quickshell/Main.qml")
    assert 'name: "searchToggleRelease"' in ilyamiro_main
    assert 'name: "searchToggleReleaseInterrupt"' in ilyamiro_main
    assert "toggle applauncher" in ilyamiro_main


def test_quickshell_dock_resolves_files_icon_and_hover_preview_position():
    app_search = read("home/desktop/quickshell/profiles/end4/ii/services/AppSearch.qml")
    launcher_apps = read("home/desktop/quickshell/profiles/end4/ii/services/LauncherApps.qml")
    dock_apps = read("home/desktop/quickshell/profiles/end4/ii/modules/ii/dock/DockApps.qml")
    dock_app_button = read("home/desktop/quickshell/profiles/end4/ii/modules/ii/dock/DockAppButton.qml")

    assert '"nemo.desktop": "nemo"' in app_search
    assert '"system-file-manager": "nemo"' in app_search
    assert "entry && iconExists(entry.icon)" in app_search
    assert '"nemo": "file-manager"' in launcher_apps
    assert "function lookupDesktopEntry(appId)" in launcher_apps
    assert "LauncherApps.launchAppId(appToplevel.appId)" in dock_app_button
    assert "root.lastHoveredButton.window" not in dock_apps
    assert "Math.min(Math.max(0, preferredX), maxX)" in dock_apps


def test_dev_profile_is_declarative_and_split():
    user = read("users/asura/default.nix")
    dev_default = read("home/dev/default.nix")
    dev_python = read("home/dev/python.nix")
    dev_ides = read("home/dev/ides.nix")
    dev_ai = read("home/dev/ai.nix")
    dev_text = "\n".join([dev_default, dev_python, dev_ides, dev_ai])
    assert "../../home/dev" in user
    assert "modules.dev" in dev_default
    assert "python3.withPackages" in dev_python
    assert "programs.vscode" in dev_ides
    assert "pkgs.\"claude-code\"" in dev_ai
    assert "pip install" not in dev_text
    assert "install-extension" not in dev_text
    assert not (REPO / "home/dev/ide.nix").exists()
    assert not (REPO / "home/dev/nanobot.nix").exists()


def test_i3_fallback_uses_nixos_xserverrc_and_user_config():
    i3_module = read("modules/desktop/i3-session.nix")
    user = read("users/asura/default.nix")
    i3_config = read("home/desktop/i3/config")
    i3status = read("home/desktop/i3/i3status.conf")
    host = read("hosts/x15xs/default.nix")

    assert "i3Session.enable = true;" in host
    assert "services.libinput.enable = true;" in i3_module
    assert "displayManager.startx" in i3_module
    assert "generateScript = true;" in i3_module
    assert 'xdg.configFile."i3/config".source = ../../home/desktop/i3/config;' in user
    assert 'home.file.".xserverrc"' in user
    assert "osConfig.services.xserver.displayManager.xserverArgs" in user
    assert "pkgs.xorg-server" in user
    assert "bindsym $mod+q kill" in i3_config
    assert "focus_follows_mouse yes" in i3_config
    assert "i3RofiTheme = ../../home/desktop/i3/rofi.rasi;" in i3_module
    assert (REPO / "home/desktop/i3/rofi.rasi").exists()
    assert "x15-i3-launcher" in i3_module
    assert "-show drun" in i3_module
    assert "-drun-match-fields name,generic,exec,categories,keywords" in i3_module
    assert "x15-i3-gestures" in i3_module
    assert "libinput-gestures" in i3_module
    assert "gesture swipe left 3 ${i3WorkspaceSwipe}/bin/x15-i3-workspace-swipe next" in i3_module
    assert "gesture swipe right 3 ${i3WorkspaceSwipe}/bin/x15-i3-workspace-swipe prev" in i3_module
    assert 'exec ${pkgs.i3}/bin/i3-msg "workspace number $target"' in i3_module
    assert "x15-i3-greenclip" in i3_module
    assert "exec --no-startup-id dex -a -s /etc/xdg/autostart" in i3_config
    assert "exec --no-startup-id x15-i3-greenclip" in i3_config
    assert "exec --no-startup-id x15-i3-gestures" in i3_config
    assert "exec --no-startup-id xss-lock --transfer-sleep-lock -- $lock" in i3_config
    assert "exec_always --no-startup-id x15-i3-apply-wallpaper" in i3_config
    assert "interval = 10" in i3status


def test_yazi_flavor_is_vendored():
    yazi = read("home/apps/yazi.nix")
    assert "fetchFromGitHub" not in yazi
    assert "./yazi/flavors/gruvbox-dark.yazi" in yazi
    assert (REPO / "home/apps/yazi/flavors/gruvbox-dark.yazi/flavor.toml").exists()


def test_no_external_ui_config_sources_remain_in_nix_files():
    text = all_text(nix_files())
    assert "illogical-flake" not in text
    assert "ilyamiro-nixos-configuration" not in text
    assert "/home/asura/Downloads" not in text
    assert "programs.illogical-impulse" not in text
    assert "fetchFromGitHub" not in text


def test_cleanup_artifacts_are_absent():
    assert not (REPO / "result").exists()
    assert not (REPO / ".pytest_cache").exists()
    assert not (REPO / ".venv").exists()
    assert not (REPO / "tests/__pycache__").exists()


def test_docs_are_centralized():
    assert (REPO / "README.md").exists()
    assert (REPO / "docs/X15_UNIFIED_WORKFLOW.md").exists()
    assert not (REPO / "END4_SETTINGS.md").exists()
    assert not (REPO / "modules/secure-boot/README.md").exists()
