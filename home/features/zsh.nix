/**
  Declarative Zsh and oh-my-zsh configuration shared across hosts.
*/
{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.file = {
    "${config.xdg.configHome}/oh-my-zsh/custom/themes/headline.zsh-theme".source =
      ./zsh/headline.zsh-theme;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    dotDir = config.home.homeDirectory;

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

    initContent = lib.mkAfter ''
      # set Headline theme values after the theme is sourced.
      HL_LAYOUT_TEMPLATE=(
        _PRE    "''${IS_SSH+ssh }"
        USER    '...'
        HOST    ' at ...'
        VENV    ' with ...'
        PATH    ' in ...'
        _SPACER ""
        BRANCH  ' on ...'
        STATUS  ' (...)'
        _POST   ""
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
      sw =
        if pkgs.stdenv.isDarwin then
          "sudo env ANIX_INSTALL_OPTIONS_FILE=/etc/anix/install-options.json darwin-rebuild switch --impure --flake $HOME/anix#amac --show-trace"
        else
          ''sudo env ANIX_INSTALL_OPTIONS_FILE=/etc/anix/install-options.json nixos-rebuild switch --impure --flake $HOME/anix#$(if [ -n "''${WSL_DISTRO_NAME:-}" ] || [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then echo apc; else echo anix; fi) --show-trace'';
      vim = "nvim";
    };
  };
}
