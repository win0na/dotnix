{
  description = ".nix, my custom nix-darwin & NixOS configuration.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nixos-hardware.url = "github:nixos/nixos-hardware";
    t2fanrd.url = "github:GnomedDev/t2fanrd";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
  };

  outputs = {
    self,
    nixpkgs,
    nixos-hardware,
    t2fanrd,
    nix-darwin,
    home-manager,
    nix-flatpak,
    nix-vscode-extensions
  } @ inputs: let
    user = "winona";
    email = "winnie@winneon.moe";
  in {
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;

    nixosConfigurations.wmac = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      specialArgs = {
        inherit self inputs user;
      };

      modules = [
        home-manager.nixosModules.home-manager {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            verbose = true;

            extraSpecialArgs = {
              inherit inputs user email;
            };

            users.winona = ./nixos/home.nix;
          };
        }

        ./nixos/config.nix
        #./nixos/pipewire_sink.nix
        ./nixos/mac_keymap.nix
        ./nixos/hardware-configuration.nix

        nixos-hardware.nixosModules.apple-t2
        t2fanrd.nixosModules.t2fanrd

        nix-flatpak.nixosModules.nix-flatpak
      ];
    };

    darwinConfigurations.wmac = nix-darwin.lib.darwinSystem {
      system = "x86_64-darwin";

      specialArgs = {
        inherit self inputs user;
      };

      modules = [
        home-manager.darwinModules.home-manager {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            verbose = true;

            extraSpecialArgs = {
              inherit inputs user email;
            };

            users.winona = ./darwin/home.nix;
          };
        }

        ./darwin/config.nix
      ];
    };
  };
}
