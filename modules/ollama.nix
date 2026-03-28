{ config, lib, pkgs, ... }:

let
  cfg = config.modules.ollama;
in
{
  options.modules.ollama = {
    enable = lib.mkEnableOption "Ollama service stack";

    preloadModel = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Preload defaultModel at boot. Disable to reduce idle heat and VRAM residency.";
    };

    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "qwen3:4b";
      description = "Model automatically loaded by ollama-model-loader";
    };

    gpuOverheadBytes = lib.mkOption {
      type = lib.types.int;
      default = 1073741824;
      description = "Reserved VRAM headroom via OLLAMA_GPU_OVERHEAD";
    };

    keepAlive = lib.mkOption {
      type = lib.types.str;
      default = "2m";
      description = "Unload model from memory after inactivity (OLLAMA_KEEP_ALIVE).";
    };

    contextLength = lib.mkOption {
      type = lib.types.int;
      default = 2048;
      description = "Context window size via OLLAMA_CONTEXT_LENGTH.";
    };

    flashAttention = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable flash attention when supported via OLLAMA_FLASH_ATTENTION.";
    };

    maxLoadedModels = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Maximum loaded models via OLLAMA_MAX_LOADED_MODELS.";
    };

    guiEnable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Open WebUI as a local Ollama GUI.";
    };

    guiHost = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Bind address for Open WebUI.";
    };

    guiPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port for Open WebUI.";
    };

    guiOpenFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for Open WebUI port.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      package = pkgs.ollama-cuda;
      loadModels = lib.optional cfg.preloadModel cfg.defaultModel;

      environmentVariables = {
        __NV_PRIME_RENDER_OFFLOAD = "1";
        OLLAMA_MAX_QUEUE = "1";
        OLLAMA_NUM_PARALLEL = "1";
        OLLAMA_GPU_OVERHEAD = toString cfg.gpuOverheadBytes;
        OLLAMA_KEEP_ALIVE = cfg.keepAlive;
        OLLAMA_CONTEXT_LENGTH = toString cfg.contextLength;
        OLLAMA_FLASH_ATTENTION = if cfg.flashAttention then "1" else "0";
        OLLAMA_MAX_LOADED_MODELS = toString cfg.maxLoadedModels;
      };
    };

    services.open-webui = lib.mkIf cfg.guiEnable {
      enable = true;
      host = cfg.guiHost;
      port = cfg.guiPort;
      openFirewall = cfg.guiOpenFirewall;
      environment = {
        OLLAMA_BASE_URL = "http://127.0.0.1:11434";
        OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
      };
    };
  };
}
