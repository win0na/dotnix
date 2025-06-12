{
  description = ".nix, my custom nix-darwin & NixOS configuration.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, nix-vscode-extensions }: let
    home_config = { pkgs, ... }: {
      home.stateVersion = "23.05";
      programs.home-manager.enable = true;

      home.sessionVariables = {
        EDITOR = "nvim";
      };

      programs.zsh = {
        enable = true;

        shellAliases = {
          vim = "nvim";
          switch = "sudo darwin-rebuild switch --flake .";
        };
      };

      programs.git = {
        enable = true;

        userName = "winneon";
        userEmail = "winnie@winneon.moe";

        ignores = [ "._*" ];

        extraConfig = {
          init.defaultBranch = "main";
          push.autoSetupRemote = true;
        };
      };

      programs.vscode = {
        enable = true;

        profiles.default.extensions = with pkgs.vscode-marketplace; [
          bbenoist.nix
        ];
      };
    };

    darwin_config = { pkgs, ... }: {
      system.configurationRevision = self.rev or self.dirtyRev or null;
      system.stateVersion = 4;

      nix.enable = false;

      nixpkgs.hostPlatform = "x86_64-darwin";
      nixpkgs.config.allowUnfree = true;

      nixpkgs.overlays = [
        nix-vscode-extensions.overlays.default
      ];

      users.users.winneon = {
        name = "winneon";
        home = "/Users/winneon";
      };

      system.primaryUser = "winneon";

      programs._1password-gui.enable = true;

      environment.systemPackages = with pkgs; [
        fastfetch neovim
      ];

      homebrew = {
        enable = true;
        onActivation.cleanup = "uninstall";

        brews = [
          "mas"
        ];

        casks = [
          "macs-fan-control"
        ];

        masApps = {
          "1Password for Safari" = 1569813296;
        };
      };

      system.defaults = {
        NSGlobalDomain."com.apple.mouse.tapBehavior" = 1;

        dock = {
          persistent-apps = [
            {
              app = "/Applications/Safari.app";
            }
            {
              app = "/System/Applications/Messages.app";
            }
            {
              app = "/System/Applications/Mail.app";
            }
            {
              app = "/System/Applications/Music.app";
            }
            {
              app = "/Users/winneon/Applications/Home Manager Apps/Visual Studio Code.app";
            }
            {
              app = "/System/Applications/Utilities/Terminal.app";
            }
            {
              app = "/System/Applications/Utilities/Activity Monitor.app";
            }
            {
              app = "/System/Applications/System Settings.app";
            }
          ];

          show-recents = false;

          persistent-others = [
            "/Users/winneon/Downloads"
          ];
        };
      };
    };
  in {
    darwinConfigurations.wmac = nix-darwin.lib.darwinSystem {
      modules = [
        home-manager.darwinModules.home-manager {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            verbose = true;

            users.winneon = home_config;
          };
        }

        darwin_config
      ];
    };
  };
}
