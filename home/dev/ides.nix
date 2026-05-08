{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.dev.ides;
  pythonPath = "${pkgs.python3}/bin/python3";
  pytestPath = "${pkgs.python3Packages.pytest}/bin/pytest";
  vscodeExtensions = with pkgs.vscode-extensions; [
    bbenoist.nix
    charliermarsh.ruff
    github.github-vscode-theme
    jnoortheen.nix-ide
    mkhl.direnv
    ms-azuretools.vscode-docker
    ms-python.black-formatter
    ms-python.debugpy
    ms-python.isort
    ms-python.python
    ms-python.vscode-pylance
    ms-toolsai.jupyter
    ms-toolsai.jupyter-keymap
    ms-toolsai.jupyter-renderers
    pkief.material-icon-theme
    redhat.vscode-yaml
    rust-lang.rust-analyzer
  ];
in
{
  config = lib.mkIf (config.modules.dev.enable && cfg.enable) {
    home.packages = with pkgs; [
      antigravity
      code-cursor
      kiro
      windsurf
    ];

    programs.vscode = {
      enable = true;
      package = pkgs.vscode;
      profiles.default = {
        extensions = vscodeExtensions;
        enableUpdateCheck = true;
        enableExtensionUpdateCheck = true;
        userSettings = {
          "extensions.autoCheckUpdates" = true;
          "extensions.autoUpdate" = true;
          "jupyter.jupyterServerType" = "local";
          "nix.enableLanguageServer" = true;
          "nix.formatterPath" = "${pkgs.nixfmt}/bin/nixfmt";
          "nix.serverPath" = "${pkgs.nil}/bin/nil";
          "python.analysis.autoImportCompletions" = true;
          "python.analysis.diagnosticMode" = "workspace";
          "python.analysis.typeCheckingMode" = "basic";
          "python.defaultInterpreterPath" = pythonPath;
          "python.languageServer" = "Pylance";
          "python.terminal.activateEnvironment" = true;
          "python.testing.pytestEnabled" = true;
          "python.testing.pytestPath" = pytestPath;
          "python.testing.unittestEnabled" = false;
          "ruff.nativeServer" = "on";
          "telemetry.telemetryLevel" = "off";
          "terminal.integrated.env.linux" = {
            PIP_DISABLE_PIP_VERSION_CHECK = "1";
            UV_PYTHON = pythonPath;
          };
          "update.mode" = "start";
          "window.commandCenter" = false;
          "workbench.colorTheme" = "GitHub Dark Dimmed";
          "workbench.iconTheme" = "material-icon-theme";
          "[nix]" = {
            "editor.defaultFormatter" = "jnoortheen.nix-ide";
            "editor.formatOnSave" = true;
          };
          "[python]" = {
            "editor.defaultFormatter" = "ms-python.black-formatter";
            "editor.formatOnSave" = true;
            "editor.codeActionsOnSave" = {
              "source.organizeImports" = "explicit";
            };
          };
        };
      };
    };

    home.file."${config.xdg.configHome}/Code/User/settings.json".force = lib.mkForce true;
  };
}
