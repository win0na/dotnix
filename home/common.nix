/**
  Home Manager configuration shared by the NixOS and nix-darwin users.
*/
{
  lib,
  pkgs,
  user,
  gitDisplayName,
  gitEmail,
  inputs,
  ...
}:
{
  imports = [
    ./features/node.nix
    ./features/python.nix
    ./features/zsh.nix
  ];

  home.stateVersion = "23.05";

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.file.".local/share/mise/plugins/nix".source = inputs.mise-nix;

  home.activation.installMiseToolchains =
    lib.hm.dag.entryAfter [ "linkGeneration" "installPackages" ]
      ''
        $DRY_RUN_CMD ${pkgs.mise}/bin/mise install python
        $DRY_RUN_CMD ${pkgs.mise}/bin/mise install node
        $DRY_RUN_CMD ${pkgs.mise}/bin/mise upgrade python
        $DRY_RUN_CMD ${pkgs.mise}/bin/mise upgrade node
      '';

  programs = {
    home-manager.enable = true;

    mise = {
      enable = true;
      package = pkgs.mise;
      enableZshIntegration = true;
    };

    git = {
      enable = true;

      ignores = [ "._*" ];

      settings = {
        user = {
          name = gitDisplayName;
          email = gitEmail;
        };

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
