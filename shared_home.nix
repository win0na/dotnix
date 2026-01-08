{ pkgs, lib, inputs, user, email, ... }: {
  home.stateVersion = "23.05";

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  accounts.email.accounts."${user}" = {
    thunderbird = {
      enable = true;
      profiles = [ user ];

      settings = id: {
        "extensions.autoDisableScopes" = 0;
        "mail.server.server_${id}.authMethod" = 10;
        "mail.smtpserver.smtp_${id}.authMethod" = 10;
      };
    };

    primary = true;
    address = email;
    flavor = "fastmail.com";
    realName = "Winona Bryan";
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
              pkgs.stdenv.isDarwin
            then
              "${pkgs._1password-gui}/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
            else
              "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
        };

        commit = {
          gpgsign = true;
        };

        user = {
          signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClBpas/q9BP1YNEKQ1w7bHm2RjTJfIimOUWBHekHjoJ";
        };
      };
    };

    nix-index.enable = true;

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
    
    thunderbird = {
      enable = true;

      profiles."${user}" = {
        isDefault = true;
      };
    };

    vscode = {
      enable = true;
      package = pkgs.vscodium;

      profiles.default.extensions = with pkgs.vscode-marketplace; [
        bbenoist.nix
        nowsci.glassit-linux
      ];
    };

    zsh = {
      enable = true;

      shellAliases = {
        sw = "sudo ${if pkgs.stdenv.isDarwin then "darwin" else "nixos"}-rebuild switch --flake $HOME/$HOST --show-trace";
        vim = "nvim";
      };
    };
  };
}