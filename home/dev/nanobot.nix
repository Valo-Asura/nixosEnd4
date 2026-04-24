{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.nanobot;
in
{
  options.modules.nanobot = {
    enable = lib.mkEnableOption "nanobot python venv";
  };

  config = lib.mkIf cfg.enable {

    xdg.configFile."nanobot/config.toml".text = ''
      # TODO: PyPI `nanobot` currently resolves to a robotics package.
      # Replace this stack with an LLM-focused tool when desired.

      [providers.ollama]
      type = "ollama"
      host = "http://127.0.0.1:11434"
      model = "qwen3:4b"

      [skills.brave_search]
      type = "brave"
      api_key = "REPLACE_ME"

      [providers.openrouter]
      type = "openrouter"
      api_key = "REPLACE_ME"
      model = "openrouter/auto"

      [orchestration]
      framework = "langgraph"
    '';

    home.activation.nanobotVenv = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -euo pipefail

      VENV_DIR="$HOME/.local/share/nanobot/.venv"
      MARKER="$VENV_DIR/.hm-py-stack-ready"
      NEED_INSTALL=0

      if [ ! -x "$VENV_DIR/bin/python" ]; then
        mkdir -p "$(dirname "$VENV_DIR")"
        ${pkgs.python3}/bin/python -m venv "$VENV_DIR"
        NEED_INSTALL=1
      fi

      if [ ! -f "$MARKER" ]; then
        NEED_INSTALL=1
      fi

      if [ "$NEED_INSTALL" -eq 1 ]; then
        "$VENV_DIR/bin/pip" install --disable-pip-version-check --upgrade pip >/dev/null
        "$VENV_DIR/bin/pip" install --disable-pip-version-check --upgrade nanobot langgraph >/dev/null
        ${pkgs.coreutils}/bin/date -u +"%Y-%m-%dT%H:%M:%SZ" > "$MARKER"
      fi
    '';
  };
}
