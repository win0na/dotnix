{ pkgs, lib, inputs, user, email, ... }: {
  imports = [ ../shared_home.nix ];

  dconf = {
    enable = true;

    settings = {
      "org/gnome/desktop/interface".color-scheme = "prefer-dark";
      "org/gnome/desktop/peripherals/touchpad".scroll-factor = 0.5;
    };
  };

  programs = {
    git = {
      enable = true;

      extraConfig = {
        gpg = {
          format = "ssh";
        };

        "gpg \"ssh\"" = {
          program = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
        };

        commit = {
          gpgsign = true;
        };

        user = {
          signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClBpas/q9BP1YNEKQ1w7bHm2RjTJfIimOUWBHekHjoJ";
        };
      };
    };

    mangohud = {
      enable = true;
      
      settings = {
        preset = 4;
      };
    };

    ssh = {
      matchBlocks = {
        "*" = {
          identityAgent = "~/.1password/agent.sock";
        };
      };
    };
  };
}
