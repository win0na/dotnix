/** Home Manager configuration shared by the NixOS and nix-darwin users. */
{ lib, pkgs, user, gitDisplayName, gitEmail, inputs, ... }: {
  imports = [
    ./features/zsh.nix
  ];

  home.stateVersion = "23.05";

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.file.".local/share/mise/plugins/nix".source = inputs.mise-nix;

  programs = {
    home-manager.enable = true;

    mise = {
      enable = true;
      package = pkgs.mise;
      enableZshIntegration = true;
    };

    git = {
      enable = true;

      userName = gitDisplayName;
      userEmail = gitEmail;
      ignores = [ "._*" ];

      extraConfig = {
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
      };
    };

    nix-index.enable = true;

    ssh = {
      enable = true;
      enableDefaultConfig = false;
    };

    vscode = {
      enable = true;
      package = pkgs.vscode;

      profiles.default.extensions = with pkgs.vscode-marketplace; [
        bbenoist.nix
        nowsci.glassit-linux
      ];
    };

  };
}
