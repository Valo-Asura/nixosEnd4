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
        cat = "bat";
        find = "fd";
        grep = "rg";
        top = "btm";
        heat = "x15-thermals";
        pwr = "x15-power-status";
        booterr = "journalctl -b -p warning --no-pager";
        fetch = "ffetch-theme";
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
        if command -v any-nix-shell >/dev/null 2>&1; then
          any-nix-shell zsh --info-right | source /dev/stdin
        fi

        if [[ -o interactive ]] && command -v ffetch-theme >/dev/null 2>&1 && [[ -t 1 ]]; then
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
