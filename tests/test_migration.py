"""
Structural verification tests for the Hyprland / Illogical Impulse stack.

Tests are run with:
  nix-shell -p python3 python3Packages.pytest python3Packages.hypothesis \
    --run "pytest tests/ --hypothesis-seed=0"
"""

import os
import re

from hypothesis import given, settings
from hypothesis import strategies as st

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def nix_file_path(relative: str) -> str:
    return os.path.join(REPO_ROOT, relative)


def read_file(relative: str) -> str:
    with open(nix_file_path(relative), "r", encoding="utf-8") as fh:
        return fh.read()


def contains_pattern(text: str, pattern: str) -> bool:
    return bool(re.search(pattern, text))


def contains_literal(text: str, literal: str) -> bool:
    return literal in text


def not_contains_literal(text: str, literal: str) -> bool:
    return literal not in text


def test_smoke_helpers():
    assert contains_literal("hello world", "world")
    assert not_contains_literal("hello world", "niri")
    assert contains_pattern("programs.hyprland.enable = true;", r"hyprland\.enable\s*=\s*true")


def test_nix_files_are_readable():
    for rel in [
        "flake.nix",
        "configuration.nix",
        "hosts/x15xs/default.nix",
        "modules/battery-care.nix",
        "modules/portal.nix",
        "users/asura/default.nix",
        "home/apps/browser.nix",
        "home/apps/mimeapps.nix",
        "home/apps/yazi.nix",
        "home/core/packages.nix",
        "home/dev/git.nix",
        "home/dev/ide.nix",
        "home/dev/nanobot.nix",
        "home/desktop/hyprland.nix",
        "home/desktop/end4/module.nix",
        "home/desktop/end4/settings.nix",
        "home/desktop/end4/overrides/ChargeLimit.qml",
        "home/desktop/end4/overrides/Todo.qml",
        "home/desktop/end4/overrides/UtilButtons.qml",
    ]:
        assert read_file(rel)


def test_github_repository_scaffolding_exists():
    for rel in [
        ".github/workflows/ci.yml",
        ".github/workflows/markdown.yml",
        ".github/PULL_REQUEST_TEMPLATE.md",
        ".markdownlint.json",
        "CONTRIBUTING.md",
    ]:
        assert os.path.exists(nix_file_path(rel))


def test_legacy_and_unused_layers_are_removed():
    assert not os.path.exists(nix_file_path("home/home.nix"))
    assert not os.path.exists(nix_file_path("home/niri.nix"))
    assert not os.path.exists(nix_file_path("home/noctalia.nix"))
    assert not os.path.exists(nix_file_path("home/waybar"))
    assert not os.path.exists(nix_file_path("home/shell/starship.toml"))


def test_flake_pins_the_target_stack():
    flake = read_file("flake.nix")
    for literal in [
        'github:hyprwm/Hyprland/v0.54.0',
        'github:soymou/illogical-flake',
        'git+https://git.outfoxxed.me/quickshell/quickshell',
        'github:InioX/matugen',
        'inputs.quickshell.follows = "quickshell";',
        "./hosts/x15xs",
        "./users/asura",
        "./home/desktop/end4/module.nix",
        "matugen = inputs.matugen.packages.",
    ]:
        assert contains_literal(flake, literal), f"Missing flake literal: {literal}"


def test_wrapper_uses_local_package_qt_and_settings_layers():
    wrapper = read_file("home/desktop/end4/module.nix")
    for literal in [
        "./packages.nix",
        "./qt.nix",
        "./settings.nix",
        "features = {",
        'enable = mkEnableOption "Enable the Illogical Impulse Hyprland configuration";',
    ]:
        assert contains_literal(wrapper, literal), f"Missing wrapper literal: {literal}"


def test_host_entrypoint_shim_forwards_to_host_folder():
    configuration = read_file("configuration.nix")
    assert contains_literal(configuration, "import ./hosts/x15xs args")
    assert not os.path.exists(nix_file_path("home/home.nix"))


def test_home_profile_enables_illogical_impulse_and_owns_theme_contract():
    home = read_file("users/asura/default.nix")
    for literal in [
        "../../home/desktop/hyprland.nix",
        "../../home/apps/browser.nix",
        "../../home/dev/ide.nix",
        "../../home/apps/mimeapps.nix",
        "stylix.enable = false;",
        'name = "Bibata-Modern-Classic";',
        'name = "adw-gtk3-dark";',
        'QT_STYLE_OVERRIDE = lib.mkForce "kvantum";',
        'QSG_RENDER_LOOP = "basic";',
        'xdg.configFile."Kvantum".enable = lib.mkForce true;',
        'xdg.configFile."foot".enable = lib.mkForce false;',
        'xdg.configFile."kitty".enable = lib.mkForce false;',
        "browser.enable = true;",
        "ide.enable = true;",
        "home.activation.migrateFootDirectory",
        'foot_dir="$HOME/.config/foot"',
        "mimeapps.enable = true;",
        'shell = "${pkgs.zsh}/bin/zsh";',
    ]:
        assert contains_literal(home, literal), f"Missing home literal: {literal}"
    assert contains_pattern(home, r"programs\.illogical-impulse\s*=\s*\{\s*enable\s*=\s*true;")


def test_browser_module_themes_firefox_and_configures_chrome():
    browser = read_file("home/apps/browser.nix")
    for literal in [
        'enable = lib.mkEnableOption "browser package set and profile tuning";',
        "zen-browser",
        "google-chrome",
        "programs.firefox = {",
        "profiles.asura = {",
        'default = "ddg";',
        "toolkit.legacyUserProfileCustomizations.stylesheets",
        "--zen-base: #0b0d10;",
        "OfferToSaveLogins = true;",
        '"signon.rememberSignons" = true;',
        "home.activation.configureChromeProfile",
        "home.activation.configureZenProfile",
        'chrome_dir="$HOME/.config/google-chrome"',
        'zen_root="$HOME/.config/zen"',
        'browser.custom_chrome_frame = true',
        'browser.theme.color_scheme = 2',
    ]:
        assert contains_literal(browser, literal), f"Missing browser literal: {literal}"


def test_ide_module_keeps_vscode_mutable_and_syncs_all_ide_settings():
    ide = read_file("home/dev/ide.nix")
    for literal in [
        'enable = lib.mkEnableOption "VS Code and related IDE tooling";',
        "code-cursor",
        "kiro",
        "antigravity",
        'package = pkgs.vscode;',
        'home.file."${config.xdg.configHome}/Code/User/settings.json".enable = lib.mkForce false;',
        "installOtherIdeExtensions",
        "configureAllIdeNixSupport",
        "ms-python.python",
        "ms-python.vscode-pylance",
        "ms-python.black-formatter",
        "ms-python.debugpy",
        "ms-python.isort",
        "ms-toolsai.jupyter",
        "ms-toolsai.jupyter-keymap",
        "ms-toolsai.jupyter-renderers",
        "charliermarsh.ruff",
        "redhat.vscode-yaml",
        "ms-azuretools.vscode-docker",
        "black",
        "debugpy",
        "ruff",
        'wanted="nil=${pkgs.nil}/bin/nil;nixfmt=${pkgs.nixfmt}/bin/nixfmt;python=${jupyterPython}/bin/python3;theme=GitHub Dark Dimmed;pythonStack=v3"',
        '"workbench.colorTheme" == "GitHub Dark Dimmed"',
        '"window.commandCenter" == false',
        '"telemetry.telemetryLevel" == "off"',
        '"update.mode" == "none"',
        '"python.languageServer" == "Pylance"',
        '"python.analysis.typeCheckingMode" == "basic"',
        '"ruff.nativeServer" == "on"',
        '"editor.defaultFormatter": "ms-python.black-formatter"',
        'merge_settings "Code"',
        'merge_settings "Cursor"',
        'merge_settings "Kiro"',
        'merge_settings "Antigravity"',
    ]:
        assert contains_literal(ide, literal), f"Missing IDE literal: {literal}"


def test_mimeapps_module_keeps_mimeapps_writable_and_seeds_defaults():
    mimeapps = read_file("home/apps/mimeapps.nix")
    for literal in [
        'enable = lib.mkEnableOption "writable MIME defaults and file-manager helpers";',
        "seededMimeDefaults = [",
        "firefox.desktop",
        "gnome-text-editor",
        "loupe",
        "papers",
        "file-roller",
        "nemo.desktop",
        "org.gnome.TextEditor.desktop",
        "org.gnome.Loupe.desktop",
        "org.gnome.Papers.desktop",
        "org.gnome.FileRoller.desktop",
        "vlc.desktop",
        '"text/html"',
        '"x-scheme-handler/http"',
        '"inode/directory"',
        '"text/plain"',
        '"image/png"',
        '"application/pdf"',
        '"application/zip"',
        '"video/mp4"',
        '"audio/ogg"',
        '"video/quicktime"',
        'xdg.configFile."mimeapps.list".enable = lib.mkForce false;',
        'xdg.dataFile."applications/mimeapps.list".enable = lib.mkForce false;',
        "home.activation.configureMimeApps",
        "ensure_regular_mime_file()",
        "/nix/store/*",
        "mimeAppsListText",
        "write_mime_file()",
    ]:
        assert contains_literal(mimeapps, literal), f"Missing MIME literal: {literal}"


def test_local_settings_module_keeps_config_mutable_and_bootstraps_dark_mode():
    settings_nix = read_file("home/desktop/end4/settings.nix")
    for literal in [
        "quickshell-patched-local",
        './overrides/Todo.qml',
        './overrides/ChargeLimit.qml',
        './overrides/UtilButtons.qml',
        'chmod u+w "$STATE_DIR"/user/generated/terminal/sequences.txt',
        '"matugen".enable = lib.mkForce false;',
        '"fuzzel".enable = lib.mkForce false;',
        '"hypr/hyprlock".enable = lib.mkForce false;',
        '"hypr/custom/scripts".enable = lib.mkForce false;',
        '"gtk-4.0/gtk.css".enable = lib.mkForce false;',
        'entryAfter [ "copyIllogicalImpulseConfigs" ]',
        'entryAfter [ "linkGeneration" ]',
        "prepareIllogicalImpulseMutableThemeOutputs",
        "mergeIllogicalImpulseSettings",
        "bootstrapQuickshellUserState",
        'target="$HOME/.config/illogical-impulse/config.json"',
        'switchwall.sh" --mode dark --noswitch',
        "matugen --source-color-index 0 --prefer closest-to-fallback \"''${matugen_args[@]}\"",
        'matugen image "$wallpaper" --mode dark',
        'ln -sfn "$HOME/.local/state/quickshell/user/generated/colors.json" "$HOME/.config/matugen/colors.json"',
        'language.ui = "en_US";',
        'calendar.locale = "en-GB";',
        'format = "hh:mm AP";',
        "enableSidebar = false;",
        "enableWorkspace = false;",
        "workspaceZoom = 1.0;",
        "radius = 64;",
        "lock.useHyprlock = false;",
        "updateInterval = 10000;",
        "historyLength = 30;",
        "pomodoro.focus = 2700;",
        "keepRightSidebarLoaded = false;",
        "showChargeLimitToggle = true;",
        "bar.weather = {",
        "enable = true;",
        "enableGPS = false;",
        'city = "Rishikesh, Uttarakhand, India 249204";',
        "useUSCS = false;",
        "fetchInterval = 10;",
        's|interval: 200|interval: 1000|',
        "$out/ii/services/ChargeLimit.qml",
        "$out/ii/modules/ii/bar/UtilButtons.qml",
        "$out/ii/services/TimerService.qml",
        's|Quickshell.execDetached(\\\\["loginctl", "lock-session"\\\\]);|GlobalStates.screenLocked = true;|',
        "GlobalStates.screenLocked = true;",
        "showChargeLimitToggle: false",
        'text: Translation.tr("Charge limit toggle")',
        'state_dir="$HOME/.local/state/quickshell/user"',
        'todo_file="$state_dir/todo.json"',
        'notes_file="$state_dir/notes.txt"',
        "type == \"array\"",
        "touch \"$notes_file\"",
        "magick identify -format '%w %h'",
        "width:-0",
        "height:-0",
        'terminalGenerationProps.forceDarkMode = true;',
        "blueman-manager",
        "nmtui",
        "nixos-rebuild switch --flake /etc/nixos#x15xs",
    ]:
        assert contains_literal(settings_nix, literal), f"Missing settings literal: {literal}"


def test_local_todo_override_recovers_from_invalid_state():
    todo_qml = read_file("home/desktop/end4/overrides/Todo.qml")
    for literal in [
        "function normalizeItem(item)",
        "function normalizeList(candidate)",
        "function persistList()",
        "function loadListFromDisk()",
        'content = content.trim()',
        'todoFileView.setText(JSON.stringify(nextList, null, 2))',
        'JSON.parse(rawText)',
        'Invalid file contents, resetting list',
        'File not found, creating new file.',
        "setDone(index, true)",
        "setDone(index, false)",
    ]:
        assert contains_literal(todo_qml, literal), f"Missing todo override literal: {literal}"


def test_charge_limit_service_reports_state_and_invokes_systemd_units():
    charge_limit = read_file("home/desktop/end4/overrides/ChargeLimit.qml")
    for literal in [
        "property bool supported: false",
        "property bool enabled: false",
        "property bool desiredEnabled: false",
        'command: [ "x15-charge-limit-status" ]',
        'root.enabled ? "x15-charge-limit-disable.service" : "x15-charge-limit-enable.service"',
        'notify-send',
        'Battery charge limit',
        "JSON.parse(text)",
    ]:
        assert contains_literal(charge_limit, literal), f"Missing charge-limit literal: {literal}"


def test_util_buttons_override_restores_valid_qml_and_charge_limit_toggle():
    util_buttons = read_file("home/desktop/end4/overrides/UtilButtons.qml")
    for literal in [
        "import qs.services",
        'onClicked: Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"]);',
        "showPerformanceProfileToggle",
        "showChargeLimitToggle",
        "onClicked: ChargeLimit.toggle()",
        'text: !ChargeLimit.supported ? "battery_alert" : (ChargeLimit.enabled ? "battery_6_bar" : "battery_full")',
    ]:
        assert contains_literal(util_buttons, literal), f"Missing util-buttons literal: {literal}"


def test_local_qt_wrapper_uses_top_level_quickshell_and_basic_render_loop():
    qt = read_file("home/desktop/end4/qt.nix")
    for literal in [
        "qsPackage = inputs.quickshell.packages.",
        "libxcb = pkgs.libxcb;",
        'export QT_QPA_PLATFORMTHEME=gtk3',
        """export QSG_RENDER_LOOP="''${QSG_RENDER_LOOP:-basic}" """.strip(),
    ]:
        assert contains_literal(qt, literal), f"Missing qt literal: {literal}"


def test_hyprland_overrides_replace_upstream_sources():
    hyprland = read_file("home/desktop/hyprland.nix")
    for literal in [
        'xdg.configFile."hypr/custom/keybinds.conf".source = lib.mkForce',
        'xdg.configFile."hypr/hyprland/keybinds.conf".source = lib.mkForce',
        'xdg.configFile."hypr/hypridle.conf".source = lib.mkForce',
        'xdg.configFile."hypr/custom/general.conf".source = lib.mkForce',
        'xdg.configFile."hypr/monitors.conf".source = lib.mkForce',
        'xdg.configFile."hypr/hyprland/general.conf".source = lib.mkForce',
        'xdg.configFile."hypr/hyprland/execs.conf".source = lib.mkForce',
        'xdg.configFile."hypr/hyprland/rules.conf".source = lib.mkForce',
    ]:
        assert contains_literal(hyprland, literal), f"Missing override literal: {literal}"


def test_hyprland_uses_classic_layout_and_perf_friendly_rules():
    hyprland = read_file("home/desktop/hyprland.nix")
    for literal in [
        '"gesture = 3, swipe, move,"',
        "monitor = eDP-1, 1920x1080@144, 0x0, 1",
        "layout = dwindle",
        "dwindle {",
        "preserve_split = true",
        "smart_split = false",
        "smart_resizing = false",
        "precise_mouse_move = true",
        "drag_threshold = 10",
        "clickfinger_behavior = false",
        "tap_button_map = lrm",
        "gestures {",
        "workspace_swipe_distance = 320",
        "workspace_swipe_create_new = true",
        "no_focus_fallback = true",
        "dim_inactive = false",
        "passes = 1",
        "enabled = false",
        "xray = false",
        "Bibata-Modern-Classic 24",
        "easyeffects --hide-window --service-mode",
        'lib.hasInfix "quickshell:" line',
        'enable_gesture = false',
        'gesture_distance = 300',
        'gesture_positive = false',
    ]:
        assert contains_literal(hyprland, literal), f"Missing Hyprland literal: {literal}"


def test_hyprland_keymap_matches_requested_classic_binds():
    hyprland = read_file("home/desktop/hyprland.nix")
    for literal in [
        "hyprMainKeybinds",
        '$mainMod = SUPER',
        '$shiftMod = SUPER SHIFT',
        '$altMod = SUPER ALT',
        '$mod = SUPER',
        "submap = global",
        'searchLauncher = pkgs.writeShellScriptBin "search-launcher"',
        'qs -p "$HOME/.config/quickshell/ii" ipc show',
        "hyprctl dispatch global quickshell:searchToggle",
        "${pkgs.fuzzel}/bin/fuzzel",
        "bindid = Super, Super_L, Toggle launcher, global, quickshell:searchToggleRelease",
        "bindid = Super, Super_R, Toggle launcher, global, quickshell:searchToggleRelease",
        "binditn = Super, catchall, global, quickshell:searchToggleReleaseInterrupt",
        "bind = Super, mouse:272, global, quickshell:searchToggleReleaseInterrupt",
        "bindn = $mainMod, Q, global, quickshell:searchToggleReleaseInterrupt",
        "bindn = $mainMod, Tab, global, quickshell:searchToggleReleaseInterrupt",
        "bindn = $shiftMod, R, global, quickshell:searchToggleReleaseInterrupt",
        'workspaceKeycodes = builtins.genList (i: "code:1${toString i}") 9;',
        "workspaceInterruptBinds = lib.concatStringsSep",
        "workspaceDispatchBinds = lib.concatStringsSep",
        "hyprIdleConf = ''",
        'hyprctl dispatch global quickshell:lock || qs -p "$HOME/.config/quickshell/ii" ipc call lock activate',
        'pkgs.writeShellScriptBin "clipboard"',
        'pkgs.writeShellScriptBin "wallpaper-switch"',
        'pkgs.writeShellScriptBin "wallpaper-random"',
        'pkgs.writeShellScriptBin "night-shift"',
        "bind = $mainMod, Q, killactive,",
        "bind = $mainMod, H, exit,",
        'pkgs.writeShellScriptBin "file-manager"',
        "bind = $mainMod, F, exec, file-manager",
        "bind = $mainMod, V, togglefloating,",
        "bind = $mainMod, J, togglesplit,",
        "bind = $mainMod, B, exec, ${pkgs.firefox}/bin/firefox",
        "bind = $mainMod, T, exec, ${pkgs.kitty}/bin/kitty",
        "bind = $mainMod, C, exec, code --enable-features=UseOzonePlatform --ozone-platform=wayland",
        "bind = $mainMod, E, exec, ${pkgs.telegram-desktop}/bin/telegram-desktop",
        "bind = $shiftMod, Tab, global, quickshell:overviewWorkspacesToggle",
        "bind = CTRL, L, global, quickshell:lock",
        "bind = $mainMod, L, global, quickshell:lock",
        "bind = $shiftMod, C, exec, clipboard",
        "bind = $mainMod, P, global, quickshell:wallpaperSelectorToggle",
        "bind = $shiftMod, P, exec, wallpaper-random",
        "bind = $shiftMod, E, exec, ${pkgs.wofi-emoji}/bin/wofi-emoji",
        "bind = $mod, F2, exec, night-shift",
        "bind = $mainMod, Left, movefocus, l",
        "bind = $mainMod, Right, movefocus, r",
        "bind = $mainMod, Up, movefocus, u",
        "bind = $mainMod, Down, movefocus, d",
        "bind = $shiftMod, Left, movewindow, l",
        "bind = $shiftMod, Right, movewindow, r",
        "bind = $shiftMod, Up, movewindow, u",
        "bind = $shiftMod, Down, movewindow, d",
        "bindm = $mod, mouse:272, movewindow",
        "bindm = $mod, mouse:273, resizewindow",
        "bindm = $mod, Control_L, movewindow",
        "bindm = $mod, ALT_L, resizewindow",
        "bind = $shiftMod, R, submap, resize",
        "submap = resize",
        "binde = , Left, resizeactive, -40 0",
        "binde = , Right, resizeactive, 40 0",
        "binde = , Up, resizeactive, 0 -40",
        "binde = , Down, resizeactive, 0 40",
        "binde = , mouse_up, resizeactive, 40 0",
        "binde = , mouse_down, resizeactive, -40 0",
        "binde = SHIFT, mouse_up, resizeactive, 0 40",
        "binde = SHIFT, mouse_down, resizeactive, 0 -40",
        "bind = , Escape, submap, global",
        "bind = , Return, submap, global",
        "bind = , Tab, submap, global",
        "bind = $shiftMod, R, submap, global",
        "bindl = , switch:Lid Switch, global, quickshell:lock",
        "Intentionally empty.",
    ]:
        assert contains_literal(hyprland, literal), f"Missing keybind literal: {literal}"
    assert not_contains_literal(hyprland, "bind = Super, Super_L, exec, search-launcher")
    assert not_contains_literal(hyprland, "bind = Super, Super_R, exec, search-launcher")
    assert not_contains_literal(hyprland, "bindn = $mainMod, W, global, quickshell:searchToggleReleaseInterrupt")
    assert not_contains_literal(hyprland, "bind = $mainMod, Space, exec, search-launcher")
    assert not_contains_literal(hyprland, "bind = SUPER, Tab, global, quickshell:overviewWorkspacesToggle")
    assert not_contains_literal(hyprland, "bindmt = SUPER SHIFT, mouse:272, movewindow")


def test_portal_module_keeps_hyprland_and_gtk_backends():
    portal = read_file("modules/portal.nix")
    assert contains_literal(portal, "services.gvfs.enable = true;")
    assert contains_literal(portal, "services.udisks2.enable = true;")
    assert contains_literal(portal, "extraPortals = lib.mkForce [")
    assert contains_literal(portal, "config.programs.hyprland.portalPackage")
    assert contains_literal(portal, "pkgs.xdg-desktop-portal-gtk")
    assert not_contains_literal(portal, 'config.common.default = lib.mkForce [ "hyprland" ];')


def test_boot_module_caps_saved_system_generations():
    boot = read_file("modules/boot.nix")
    assert contains_literal(boot, 'windowsEspPartUuid = "2e64ad33-87cf-49fc-971a-ef00da61c67b";')
    assert contains_literal(boot, "linuxPackages_7_0")
    assert contains_literal(boot, "pkgs.linuxPackages_zen")
    assert contains_literal(boot, "limine = {")
    assert contains_literal(boot, "maxGenerations = 7;")
    assert contains_literal(boot, 'windowsBootManagerPath = "/EFI/Microsoft/Boot/bootmgfw.efi";')
    assert contains_literal(boot, "path: guid(${windowsEspPartUuid}):${windowsBootManagerPath}")
    assert contains_literal(boot, "boot() resource only addresses partitions on the boot drive")


def test_nix_gc_and_store_optimisation_are_enabled():
    configuration = read_file("hosts/x15xs/default.nix")
    for literal in [
        "auto-optimise-store = true;",
        "max-jobs = \"auto\";",
        "cores = 0;",
        "min-free = 1073741824;",
        "max-free = 5368709120;",
        "keep-outputs = true;",
        "keep-derivations = true;",
        "automatic = true;",
        'dates = "Sun 04:30";',
        'options = "--delete-older-than 7d";',
        "persistent = false;",
        'dates = [ "Sun 05:30" ];',
        'randomizedDelaySec = "45m";',
    ]:
        assert contains_literal(configuration, literal), f"Missing Nix optimisation literal: {literal}"


def test_hybrid_gpu_and_ollama_defaults_stay_resource_oriented():
    configuration = read_file("hosts/x15xs/default.nix")
    nvidia = read_file("modules/nvidia.nix")

    for literal in [
        'keepAlive = "2m";',
        "guiEnable = false;",
        '"nvidia.NVreg_TemporaryFilePath=/var/tmp"',
        "batteryCare = {",
        "stopThreshold = 90;",
        "defaultEnabled = true;",
    ]:
        assert contains_literal(configuration, literal), f"Missing configuration literal: {literal}"

    for literal in [
        "powerManagement = {",
        "enable = true;",
        "finegrained = true;",
        "enableOffloadCmd = true;",
    ]:
        assert contains_literal(nvidia, literal), f"Missing NVIDIA literal: {literal}"


def test_networking_error_noise_fixes_are_enabled():
    configuration = read_file("hosts/x15xs/default.nix")
    for literal in [
        'networking.networkmanager.dns = "systemd-resolved";',
        "services.resolved.enable = true;",
        "systemd.services.systemd-rfkill.enable = lib.mkForce true;",
        "systemd.sockets.systemd-rfkill.enable = lib.mkForce true;",
        "services.gnome.gnome-keyring.enable = true;",
        "security.pam.services.greetd.enableGnomeKeyring = true;",
        "hardware.bluetooth = {",
        "powerOnBoot = true;",
        "FastConnectable = true;",
        'JustWorksRepairing = "always";',
        'Privacy = "device";',
        "wsdd",
    ]:
        assert contains_literal(configuration, literal), f"Missing networking/runtime fix literal: {literal}"


def test_battery_care_module_exposes_helpers_and_polkit_scope():
    battery_care = read_file("modules/battery-care.nix")
    for literal in [
        'enable = lib.mkEnableOption "battery charge limit helpers";',
        "default = 90;",
        "default = true;",
        'default = "asura";',
        "x15-charge-limit-status",
        "x15-charge-limitctl",
        "x15-charge-limit-enable",
        "x15-charge-limit-disable",
        "x15-charge-limit-restore",
        "charge_control_end_threshold",
        "charging_profile",
        "org.freedesktop.systemd1.manage-units",
        'subject.user !== "${cfg.user}"',
        "requestedStopThreshold",
        "desiredEnabled",
    ]:
        assert contains_literal(battery_care, literal), f"Missing battery-care literal: {literal}"


def test_vscode_settings_stay_mutable():
    ide = read_file("home/dev/ide.nix")
    assert not_contains_literal(ide, "userSettings = {")
    assert contains_literal(
        ide,
        'home.file."${config.xdg.configHome}/Code/User/settings.json".enable = lib.mkForce false;',
    )
    assert contains_literal(ide, "settings_need_merge() {")
    assert contains_literal(ide, "for app in Code Cursor Kiro Antigravity; do")


def test_packages_module_drops_duplicate_gui_file_managers():
    packages = read_file("home/core/packages.nix")
    assert contains_literal(packages, "nemo")
    assert contains_literal(packages, "uv")
    assert contains_literal(packages, "ollama")
    assert contains_literal(packages, 'pkgs."claude-code"')
    assert contains_literal(packages, "python3")
    assert contains_literal(packages, "python3Packages.conda")
    assert contains_literal(packages, "python3Packages.jupyterlab")
    assert contains_literal(packages, "vlc")
    assert not_contains_literal(packages, "nautilus")
    assert not_contains_literal(packages, "thunar")
    assert not_contains_literal(packages, "programs.firefox")


def test_docs_match_the_current_end4_stack():
    readme = read_file("README.md")
    end4_settings = read_file("END4_SETTINGS.md")
    hyprland_controls = read_file("HYPRLAND_CONTROLS.md")

    assert contains_literal(readme, "Compositor/Shell: `Hyprland 0.54` + Illogical Impulse / QuickShell")
    assert contains_literal(readme, "git+https://git.outfoxxed.me/quickshell/quickshell")
    assert contains_literal(readme, "Persistent end-4 defaults are merged into `~/.config/illogical-impulse/config.json`")
    assert contains_literal(readme, "toggle the current dwindle split")
    assert contains_literal(readme, "general.layout = dwindle")
    assert contains_literal(readme, "Super+Tab")
    assert contains_literal(readme, "Super+Shift+R")
    assert contains_literal(readme, "Nemo")
    assert contains_literal(readme, "Super+Ctrl")
    assert contains_literal(readme, "Super+Alt")
    assert contains_literal(readme, "tap/release Super")
    assert contains_literal(readme, "3-finger horizontal swipe")
    assert contains_literal(readme, "1920x1080@144")
    assert contains_literal(readme, "hypr/hyprland/keybinds.conf")
    assert contains_literal(readme, "custom/keybinds.conf")
    assert contains_literal(readme, "global submap")
    assert contains_literal(readme, "mimeapps.list")
    assert contains_literal(readme, "Firefox is the default web handler")
    assert contains_literal(readme, "Open WebUI disabled by default")
    assert contains_literal(readme, "hosts/x15xs/default.nix")
    assert contains_literal(readme, "users/asura/default.nix")
    assert contains_literal(readme, "home/apps/mimeapps.nix")
    assert contains_literal(readme, "home/desktop/end4/settings.nix")
    assert contains_literal(readme, "VLC is installed declaratively")
    assert contains_literal(readme, "battery-care target `90%`")
    assert contains_literal(readme, "bar charge-limit button shown by default")
    assert contains_literal(readme, "Python, Pylance, Black, isort, Ruff, Jupyter helpers, YAML, Docker")
    assert contains_literal(readme, "latest `7` system generations")
    assert contains_literal(readme, "weekly garbage collection")
    assert contains_literal(readme, '`time.format = "hh:mm AP"`')
    assert contains_literal(readme, '`time.pomodoro.focus = 2700` (`45m`)')
    assert contains_literal(readme, 'Rishikesh, Uttarakhand, India 249204')
    assert contains_literal(readme, '`background.parallax.enableWorkspace = false`')
    assert contains_literal(readme, '`lock.useHyprlock = false`')
    assert contains_literal(readme, "todo.json")
    assert contains_literal(end4_settings, "background.parallax.enableSidebar = false")
    assert contains_literal(end4_settings, 'language.ui = "en_US"')
    assert contains_literal(end4_settings, 'time.format = "hh:mm AP"')
    assert contains_literal(end4_settings, 'time.pomodoro.focus = 2700')
    assert contains_literal(end4_settings, 'lock.useHyprlock = false')
    assert contains_literal(end4_settings, 'bar.utilButtons.showChargeLimitToggle = true')
    assert contains_literal(end4_settings, "restores a `90%` stop-charge target")
    assert contains_literal(end4_settings, "QuickShell/PAM is the primary lockscreen provider")
    assert contains_literal(end4_settings, "Wallpapers below `1920x1080`")
    assert contains_literal(end4_settings, 'Rishikesh, Uttarakhand, India 249204')
    assert contains_literal(end4_settings, "todo.json")
    assert contains_literal(hyprland_controls, "Super+Left/Right/Up/Down")
    assert contains_literal(hyprland_controls, "Super+J")
    assert contains_literal(hyprland_controls, "Super+Tab")
    assert contains_literal(hyprland_controls, "Super+Shift+R")
    assert contains_literal(hyprland_controls, "Super+Ctrl")
    assert contains_literal(hyprland_controls, "Super+Alt")
    assert contains_literal(hyprland_controls, "tap/release Super")
    assert contains_literal(hyprland_controls, "lock with QuickShell")
    assert contains_literal(hyprland_controls, "launch Firefox")
    assert contains_literal(hyprland_controls, "home/desktop/hyprland.nix")
    assert contains_literal(hyprland_controls, "hypr/hyprland/keybinds.conf")
    assert contains_literal(hyprland_controls, "custom/keybinds.conf")
    assert not_contains_literal(readme, "Super+W")
    assert not_contains_literal(hyprland_controls, "Super+W")
    assert not os.path.exists(nix_file_path("PLAN.md"))
    assert not os.path.exists(nix_file_path("KEYBINDINGS.md"))
    assert os.path.exists(nix_file_path("END4_SETTINGS.md"))
    assert os.path.exists(nix_file_path("HYPRLAND_CONTROLS.md"))


@settings(max_examples=100)
@given(st.just(read_file("flake.nix")))
def test_property_flake_is_non_empty_text(flake_content: str):
    assert isinstance(flake_content, str)
    assert len(flake_content) > 0
