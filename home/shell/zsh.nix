{ config, lib, pkgs, ... }:

let
  cfg = config.modules.shell;
in
{
  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autocd = true;
      history = {
        path = "${config.xdg.dataHome}/zsh/history";
        size = 50000;
        save = 50000;
        ignoreDups = true;
        ignoreSpace = true;
        extended = true;
        share = true;
      };

      shellAliases = {
        ll = "eza -la --git";
        cls = "clear";
        cat = "bat";
        find = "fd";
        grep = "rg";
        top = "btm";
        heat = "x15-thermals";
        pwr = "x15-power-status";
        fans = "x15-sensors status";
        booterr = "journalctl -b -p warning --no-pager";
        fetch = "ffetch-theme";
        cam = "snapshot";
        mic = "pwvucontrol";
        pipes = "crosspipe";
      };

      plugins = [
        {
          name = "zsh-autosuggestions";
          src = pkgs.zsh-autosuggestions;
          file = "share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh";
        }
        {
          name = "fast-syntax-highlighting";
          src = pkgs.zsh-fast-syntax-highlighting;
          file = "share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh";
        }
      ];

      initContent = ''
        bindkey -e
        setopt auto_pushd pushd_ignore_dups hist_reduce_blanks hist_verify interactive_comments
        unsetopt beep
        zstyle ':completion:*' menu select
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
        zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"

        if command -v any-nix-shell >/dev/null 2>&1; then
          any-nix-shell zsh --info-right | source /dev/stdin
        fi

        if [[ -o interactive ]] &&
           command -v ffetch-theme >/dev/null 2>&1 &&
           [[ -t 1 ]] &&
           [[ "''${FASTFETCH_ON_STARTUP:-1}" = 1 ]] &&
           [[ -z "''${SSH_CONNECTION:-}" ]]; then
          ffetch-theme
        fi

        ai() {
          if [[ $# -eq 0 ]]; then
            printf '%s\n' "usage: ai <prompt>"
            return 1
          fi
          local payload
          payload="$(${pkgs.jq}/bin/jq -cn --arg prompt "$*" '{model:"qwen3:4b", prompt:$prompt, stream:false}')"
          curl -sS http://127.0.0.1:11434/api/generate \
            -H 'Content-Type: application/json' \
            -d "$payload" \
            | ${pkgs.jq}/bin/jq -r '.response // empty'
        }
      '';
    };

    home.packages = [ pkgs.any-nix-shell ];
  };
}
