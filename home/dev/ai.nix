{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.dev.ai;
in
{
  config = lib.mkIf (config.modules.dev.enable && cfg.enable) {
    home.packages = [
      pkgs.ollama
      pkgs."claude-code"
    ];

    xdg.configFile."nanobot/config.toml".text = ''
      [providers.ollama]
      type = "ollama"
      host = "http://127.0.0.1:11434"
      model = "qwen3:4b"

      [orchestration]
      framework = "langgraph"
    '';
  };
}
