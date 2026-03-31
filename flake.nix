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

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mise-nix.url = "github:jbadeau/mise-nix";

    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    jovian = {
      url = "github:jovian-experiments/jovian-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

    kwin-effects-forceblur = {
      url = "github:taj-ny/kwin-effects-forceblur";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # misc inputs
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    sddm-stray.url = "github:bqrry4/sddm-stray";

    solaar = {
      url = "https://flakehub.com/f/svenum/solaar-flake/*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    librepods = {
      url = "github:kavishdevar/librepods/c852b726deb5344ea3637332722a7c93f3858d60";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    inputactions = {
      url = "github:taj-ny/inputactions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = {
    self,
    nixpkgs,
    nixos-hardware,
    nix-darwin,
    home-manager,
    nixos-wsl,
    mise-nix,
    chaotic,
    jovian,
    nix-flatpak,
    nixos-facter-modules,
    kwin-effects-forceblur,
    disko,
    nix-vscode-extensions,
    sddm-stray,
    solaar,
    librepods,
    inputactions
  } @ inputs: let
    system = "x86_64-linux";
    user = "winona";
    email = "winnie@winneon.moe";
    wnixMode = "bare";
  in {
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;

    nixosConfigurations.wnix = nixpkgs.lib.nixosSystem {
      system = system;

      specialArgs = {
        inherit self inputs user wnixMode;
        hostname = "wnix";
      };

      modules = [
        home-manager.nixosModules.home-manager {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            verbose = true;

            extraSpecialArgs = {
              inherit inputs user email wnixMode;
            };

            users.winona = ./nixos/home/default.nix;
          };
        }

        ./nixos/default.nix

        chaotic.nixosModules.default
      ] ++ nixpkgs.lib.optionals (wnixMode == "bare") [
        ./nixos/disk.nix
        jovian.nixosModules.default
        nix-flatpak.nixosModules.nix-flatpak
        disko.nixosModules.disko
        solaar.nixosModules.default

        (nixos-facter-modules.nixosModules.facter {
          config.facter.reportPath =
            if builtins.pathExists ./facter.json then ./facter.json
            else
              throw "dotnix: create a facter.json using '--generate-hardware-config nixos-facter ./facter.json'";
        })
      ] ++ nixpkgs.lib.optionals (wnixMode == "wsl") [
        nixos-wsl.nixosModules.default
      ];
    };

    darwinConfigurations.wmac = nix-darwin.lib.darwinSystem {
      system = "x86_64-darwin";

      specialArgs = {
        inherit self inputs user;
        hostname = "wmac";
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
