/** Declarative Zsh and oh-my-zsh configuration shared across hosts. */
{ config, lib, pkgs, ... }: {
  home.file = {
    "${config.xdg.configHome}/oh-my-zsh/custom/themes/headline/headline.zsh-theme".source = ./zsh/headline.zsh-theme;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 50000;
      save = 50000;
      share = true;
      ignoreSpace = true;
      ignoreDups = true;
      extended = true;
    };

    oh-my-zsh = {
      enable = true;
      custom = "${config.xdg.configHome}/oh-my-zsh/custom";
      theme = "headline";
      plugins = [
        "git"
        "sudo"
      ];
    };

    initExtra = lib.mkAfter ''
      # set Headline theme values after the theme is sourced.
      HL_LAYOUT_TEMPLATE=(
        _PRE    "''${IS_SSH+ssh }"
        USER    '...'
        HOST    ' at ...'
        VENV    ' with ...'
        PATH    ' in ...'
        _SPACER ''
        BRANCH  ' on ...'
        STATUS  ' (...)'
        _POST   ''
      )

      HL_CONTENT_TEMPLATE=(
        USER   "%{$bold$red%} ..."
        HOST   "%{$bold$yellow%}󰇅 ..."
        VENV   "%{$bold$green%} ..."
        PATH   "%{$bold$blue%} ..."
        BRANCH "%{$bold$cyan%} ..."
        STATUS "%{$bold$magenta%}..."
      )

      HL_GIT_COUNT_MODE='on'
      HL_GIT_SEP_SYMBOL='|'
      HL_GIT_STATUS_SYMBOLS[CONFLICTS]="%{$red%}✘"
      HL_GIT_STATUS_SYMBOLS[CLEAN]="%{$green%}✔"
      HL_CLOCK_MODE='on'
      HL_CLOCK_SOURCE="date +%+"
      HL_ERR_MODE='detail'
    '';

    shellAliases = {
      node-install-latest = "mise use -g node@latest";
      sw =
        if pkgs.stdenv.isDarwin then
          ''sudo darwin-rebuild switch --flake $HOME/a.nix#amac --show-trace''
        else
          ''sudo nixos-rebuild switch --flake $HOME/a.nix#$(case "$HOST" in
            a.nix) echo anix ;;
            a.pc) echo apc ;;
            *) printf '%s\n' "a.nix: unsupported linux host '$HOST' for sw alias" >&2; exit 1 ;;
          esac) --show-trace'';
        vim = "nvim";
      };
  };
}
