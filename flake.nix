{
  description = ".nix, my custom nix-darwin & NixOS configuration.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nix-darwin, nixpkgs }: let
    darwin_config = { pkgs, ... }: {
      system.configurationRevision = self.rev or self.dirtyRev or null;
      system.stateVersion = 4;

      nix.enable = false;

      nixpkgs.hostPlatform = "x86_64-darwin";
      nixpkgs.config.allowUnfree = true;

      users.users.winneon = {
        name = "winneon";
        home = "/Users/winneon";
      };

      system.primaryUser = "winneon";

      programs.zsh.enable = true;
      programs._1password-gui.enable = true;

      environment.systemPackages = with pkgs; [
        fastfetch neovim vscode-with-extensions
      ];

      environment.shellAliases = {
        vim = "nvim";
      };

      environment.variables = {
        EDITOR = "nvim";
      };
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

      system.defaults.dock = {
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
            app = "/Applications/Nix Apps/Visual Studio Code.app";
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
  in {
    darwinConfigurations.wmac = nix-darwin.lib.darwinSystem {
      modules = [ darwin_config ];
    };
  };
}