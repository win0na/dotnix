{ pkgs, lib, inputs, user, email, ... }: {
  home.stateVersion = "23.05";

  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  programs.zsh = {
    enable = true;

    shellAliases = {
      darwin_switch = "sudo darwin-rebuild switch --flake .";
      nixos_switch = "sudo nixos-rebuild switch --flake .";

      vim = "nvim";
    };
  };

  programs.git = {
    enable = true;

    userName = user;
    userEmail = email;

    ignores = [ "._*" ];

    extraConfig = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };

  programs.gpg.enable = true;
  services.gpg-agent.enable = true;

  programs.vscode = {
    enable = true;

    profiles.default.extensions = with pkgs.vscode-marketplace; [
      bbenoist.nix
    ];
  };
}