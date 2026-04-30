{ config, lib, pkgs, ... }:

let
  cfg = config.modules.ollama;
  searxngPort = 8888;
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
      default = "phi4-mini:3.8b";
      description = "Model automatically loaded by ollama-model-loader. phi4-mini:3.8b = ~2.3GB VRAM, fastest reasoning on RTX 3050 4GB.";
    };

    gpuOverheadBytes = lib.mkOption {
      type = lib.types.int;
      default = 536870912; # 512 MB
      description = "Reserved VRAM headroom via OLLAMA_GPU_OVERHEAD";
    };

    keepAlive = lib.mkOption {
      type = lib.types.str;
      default = "2m";
      description = "Unload model from memory after inactivity (OLLAMA_KEEP_ALIVE).";
    };

    contextLength = lib.mkOption {
      type = lib.types.int;
      default = 4096;
      description = "Context window size via OLLAMA_CONTEXT_LENGTH. phi4-mini:3.8b fits in 4GB VRAM with 4k context.";
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

    # Constrain Ollama's resource footprint — keeps desktop responsive during inference.
    systemd.services.ollama.serviceConfig = {
      MemoryHigh = "512M";
      MemoryMax  = "3G";
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "80%";
      CPUSchedulingPolicy = "batch";
      CPUWeight = 50;
      IOWeight  = 50;
    };

    # ── SearXNG: local privacy-respecting web search ──────────────────────────
    # Provides Open WebUI's RAG web search backend at localhost:8888.
    # No external API key required.
    services.searx = {
      enable = true;
      package = pkgs.searxng;
      runInUwsgi = false;
      settings = {
        server = {
          port = searxngPort;
          bind_address = "127.0.0.1";
          secret_key = "nixos-x15xs-searxng-local-only";
          limiter = false;       # local only, no rate limiting needed
          image_proxy = true;
          public_instance = false;
        };
        ui = {
          static_use_hash = true;
          default_locale = "en";
          query_in_title = true;
          results_on_new_tab = false;
          default_theme = "simple";
        };
        search = {
          safe_search = 0;
          autocomplete = "";
          default_lang = "en";
          ban_time_on_fail = 5;
          max_ban_time_on_fail = 120;
        };
        outgoing = {
          request_timeout = 8.0;
          max_request_timeout = 15.0;
          pool_connections = 100;
          pool_maxsize = 20;
        };
        # Enable fast, reliable engines for AI-assisted web search.
        engines = [
          { name = "google";        engine = "google";        categories = "general, web"; disabled = false; }
          { name = "ddg";           engine = "duckduckgo";    categories = "general, web"; disabled = false; }
          { name = "brave";         engine = "brave";         categories = "general, web"; disabled = false; }
          { name = "wikipedia";     engine = "wikipedia";     categories = "general";      disabled = false; }
          { name = "github";        engine = "github";        categories = "it";           disabled = false; }
          { name = "stackoverflow"; engine = "stackoverflow"; categories = "it";           disabled = false; }
          { name = "arxiv";         engine = "arxiv";         categories = "science";      disabled = false; }
        ];
      };
    };

    # ── Open WebUI with SearXNG + tool integration ────────────────────────────
    services.open-webui = lib.mkIf cfg.guiEnable {
      enable = true;
      host = cfg.guiHost;
      port = cfg.guiPort;
      openFirewall = cfg.guiOpenFirewall;
      environment = {
        OLLAMA_BASE_URL     = "http://127.0.0.1:11434";
        OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";

        # ── RAG Web Search (SearXNG backend) ──────────────────────────────────
        ENABLE_RAG_WEB_SEARCH = "true";
        RAG_WEB_SEARCH_ENGINE = "searxng";
        SEARXNG_QUERY_URL     = "http://127.0.0.1:${toString searxngPort}/search?q=<query>&format=json&language=en";

        # Number of results to fetch per web search query.
        RAG_WEB_SEARCH_RESULT_COUNT = "5";
        RAG_WEB_SEARCH_CONCURRENT_REQUESTS = "10";

        # ── Tool / function calling support ───────────────────────────────────
        # Enables the tool-calling interface in the UI (models with tools: true).
        ENABLE_TOOLS = "true";

        # ── Performance / privacy ─────────────────────────────────────────────
        # Disable telemetry and external calls on a local-only install.
        SCARF_NO_ANALYTICS  = "true";
        DO_NOT_TRACK        = "1";
        ANONYMIZED_TELEMETRY = "false";

        # Disable OAuth / external auth (local single-user).
        WEBUI_AUTH = "false";

        # Cache embeddings locally.
        RAG_EMBEDDING_ENGINE = "";  # Use local Ollama embeddings
      };
    };
  };
}
