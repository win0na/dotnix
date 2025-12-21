{
  description = ".nix, my custom nix-darwin & NixOS configuration.";

  inputs = {
    # nix system inputs
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixos-hardware.url = "github:nixos/nixos-hardware";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    jovian = {
      url = "github:jovian-experiments/jovian-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # utility inputs
    t2fanrd.url = "github:GnomedDev/t2fanrd";

    # misc inputs
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixos-hardware,
    nix-darwin,
    home-manager,
    chaotic,
    jovian,
    nix-flatpak,
    nixos-facter-modules,
    disko,
    t2fanrd,
    nix-vscode-extensions,
    zen-browser
  } @ inputs: let
    user = "winona";
    email = "winnie@winneon.moe";
  in {
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;

    nixosConfigurations.willow = nixpkgs.lib.nixosSystem {
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
        ./nixos/mac_keymap.nix
        ./nixos/disk.nix
        ./nixos/hardware-configuration.nix

        chaotic.nixosModules.default
        jovian.nixosModules.default
        nix-flatpak.nixosModules.nix-flatpak
        disko.nixosModules.disko
        t2fanrd.nixosModules.t2fanrd

        nixos-facter-modules.nixosModules.facter {
          config.facter.reportPath =
            if builtins.pathExists ./facter.json then
              ./facter.json
            else
              throw "fail: run nixos-anywhere with `--generate-hardware-config nixos-facter ./facter.json`";
        }
      ];
    };

    nixosConfigurations.ryder = nixpkgs.lib.nixosSystem {
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
        ./nixos/mac_keymap.nix
        ./nixos/disk.nix
        ./nixos/hardware-configuration.nix

        nixos-hardware.nixosModules.apple-t2
        chaotic.nixosModules.default
        jovian.nixosModules.default
        nix-flatpak.nixosModules.nix-flatpak
        disko.nixosModules.disko
        t2fanrd.nixosModules.t2fanrd

        nixos-facter-modules.nixosModules.facter {
          config.facter.reportPath =
            if builtins.pathExists ./facter.json then
              ./facter.json
            else
              throw "fail: run nixos-anywhere with `--generate-hardware-config nixos-facter ./facter.json`";
        }
      ];
    };

    darwinConfigurations.ryder = nix-darwin.lib.darwinSystem {
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
