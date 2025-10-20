{ pkgs, lib, inputs, user, email, ... }: {
  home.stateVersion = "23.05";

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;

      userName = user;
      userEmail = email;
      ignores = [ "._*" ];

      extraConfig = {
        init.defaultBranch = "main";
        push.autoSetupRemote = true;

        gpg = {
          format = "ssh";
        };

        "gpg \"ssh\"" = {
          program =
            if
              pkgs.stdenv.isLinux
            then
              "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}"
            else
              "${pkgs._1password-gui}/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
        };

        commit = {
          gpgsign = true;
        };

        user = {
          signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClBpas/q9BP1YNEKQ1w7bHm2RjTJfIimOUWBHekHjoJ";
        };
      };
    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;

      matchBlocks."*" = {
        identityAgent =
          if
            pkgs.stdenv.isLinux
          then
            "~/.1password/agent.sock"
          else
            "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
      };
    };

    vscode = {
      enable = true;

      profiles.default.extensions = with pkgs.vscode-marketplace; [
        bbenoist.nix
      ];
    };

    zsh = {
      enable = true;

      shellAliases = {
        darwin_switch = "sudo darwin-rebuild switch --flake .";
        nixos_switch = "sudo nixos-rebuild switch --flake .";

        vim = "nvim";
      };
    };
  };
}