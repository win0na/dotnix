{
  description = "anix (/æ nɪx/), my custom nix-darwin & NixOS configuration.";

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

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mise-nix = {
      url = "github:jbadeau/mise-nix";
      flake = false;
    };

    jovian = {
      url = "github:jovian-experiments/jovian-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
    nixos-facter = {
      url = "github:numtide/nixos-facter";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
      url = "git+https://github.com/taj-ny/inputactions?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    allynx = {
      url = "github:win0na/a.llynx";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    opencode = {
      url = "github:anomalyco/opencode";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-hardware,
      nix-darwin,
      home-manager,
      sops-nix,
      nixos-wsl,
      mise-nix,
      jovian,
      nix-flatpak,
      nixos-facter,
      nixos-facter-modules,
      kwin-effects-forceblur,
      disko,
      nix-vscode-extensions,
      sddm-stray,
      solaar,
      librepods,
      inputactions,
      allynx,
      hermes-agent,
      opencode,
    }@inputs:
    let
      system = "x86_64-linux";
      darwinSystem = "x86_64-darwin";
      sharedNixpkgsPolicy = import ./common/nixpkgs-policy.nix { inherit inputs; };
      mkPkgs =
        {
          system,
          extraOverlays ? [ ],
          allowDeprecatedx86_64Darwin ? false,
        }:
        import nixpkgs {
          inherit system;
          config =
            sharedNixpkgsPolicy.config
            // nixpkgs.lib.optionalAttrs allowDeprecatedx86_64Darwin {
              inherit allowDeprecatedx86_64Darwin;
            };
          overlays = sharedNixpkgsPolicy.overlays ++ extraOverlays;
        };
      installDefaultsFile = builtins.readFile ./scripts/lib/install/defaults.sh;
      installDefaults = builtins.listToAttrs (
        map
          (
            line:
            let
              match = builtins.match ''([[:space:]]*export[[:space:]]+)?([A-Z0-9_]+)="(.*)"'' line;
            in
            if match == null then
              throw "anix: invalid installer default line: ${line}"
            else
              {
                name = builtins.elemAt match 1;
                value = builtins.elemAt match 2;
              }
          )
          (
            builtins.filter (line: line != "" && builtins.match "[[:space:]]*#.*" line == null) (
              nixpkgs.lib.splitString "\n" installDefaultsFile
            )
          )
      );
      defaultInstallOptions = {
        user = installDefaults.ANIX_DEFAULT_USER;
        gitDisplayName = installDefaults.ANIX_DEFAULT_GIT_DISPLAY_NAME;
        gitEmail = installDefaults.ANIX_DEFAULT_GIT_EMAIL;
        gitSigningKey = installDefaults.ANIX_DEFAULT_GIT_SIGNING_KEY;
        sshAuthorizedKeys = [ installDefaults.ANIX_DEFAULT_SSH_AUTHORIZED_KEY ];
        hostnames = {
          anix = installDefaults.ANIX_DEFAULT_HOSTNAME_ANIX;
          apc = installDefaults.ANIX_DEFAULT_HOSTNAME_APC;
          amac = installDefaults.ANIX_DEFAULT_HOSTNAME_AMAC;
        };
      };
      installOptions = nixpkgs.lib.recursiveUpdate defaultInstallOptions (
        let
          envPath = builtins.getEnv "ANIX_INSTALL_OPTIONS_FILE";
          persistentPath = "/etc/anix/install-options.json";
          path = if envPath != "" then envPath else persistentPath;
          rawInstallOptions =
            if builtins.pathExists path then builtins.fromJSON (builtins.readFile path) else { };
        in
        rawInstallOptions
        //
          nixpkgs.lib.optionalAttrs
            (rawInstallOptions ? rootSshAuthorizedKeys && !(rawInstallOptions ? sshAuthorizedKeys))
            {
              sshAuthorizedKeys = rawInstallOptions.rootSshAuthorizedKeys;
            }
      );
      commonHmSpecialArgs = {
        inherit inputs;
        user = installOptions.user;
        gitDisplayName = installOptions.gitDisplayName;
        gitEmail = installOptions.gitEmail;
        gitSigningKey = installOptions.gitSigningKey;
        sshAuthorizedKeys = installOptions.sshAuthorizedKeys;
      };
      mkSystemSpecialArgs =
        {
          hostname,
          extraArgs ? { },
        }:
        {
          inherit self inputs hostname;
          user = installOptions.user;
          sshAuthorizedKeys = installOptions.sshAuthorizedKeys;
        }
        // extraArgs;
      mkHomeManagerModules =
        {
          hmModule,
          userModule,
          extraSpecialArgs ? { },
        }:
        [
          hmModule
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              verbose = true;
              sharedModules = [ inputs.sops-nix.homeManagerModules.sops ];

              extraSpecialArgs = commonHmSpecialArgs // extraSpecialArgs;

              users.${installOptions.user} = userModule;
            };
          }
        ];
      aLlynx = inputs.allynx;
      darwinPkgs = mkPkgs {
        system = darwinSystem;
        allowDeprecatedx86_64Darwin = true;
      };
      darwinToolPkgs = mkPkgs {
        system = darwinSystem;
        allowDeprecatedx86_64Darwin = true;
        extraOverlays = [ nix-darwin.overlays.default ];
      };

      mkANixSystem =
        hostProfile: hostname:
        nixpkgs.lib.nixosSystem {
          system = system;

          specialArgs = mkSystemSpecialArgs {
            inherit hostname;
            extraArgs = { inherit hostProfile; };
          };

          modules =
            mkHomeManagerModules {
              hmModule = home-manager.nixosModules.home-manager;
              userModule = ./nixos/home/default.nix;
              extraSpecialArgs = { inherit hostProfile; };
            }
            ++ [
              hermes-agent.nixosModules.default
              ./nixos/default.nix

            ]
            ++ nixpkgs.lib.optionals (hostProfile == "bare") [
              ./nixos/disk.nix
              jovian.nixosModules.default
              nix-flatpak.nixosModules.nix-flatpak
              disko.nixosModules.disko
              solaar.nixosModules.default

              nixos-facter-modules.nixosModules.facter
              {
                facter.reportPath =
                  let
                    envPath = builtins.getEnv "ANIX_FACTER_REPORT_PATH";
                    persistentPath = "/etc/anix/facter.json";
                  in
                  if envPath != "" && builtins.pathExists envPath then
                    envPath
                  else if builtins.pathExists persistentPath then
                    persistentPath
                  else
                    null;
              }
            ]
            ++ nixpkgs.lib.optionals (hostProfile == "wsl") [
              nixos-wsl.nixosModules.default
            ];
        };
    in
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
      packages.x86_64-linux.allynx =
        aLlynx.packages.${system}.allynx or aLlynx.packages.${system}.default;
      packages.x86_64-linux.disko = disko.packages.${system}.disko or disko.packages.${system}.default;
      packages.x86_64-linux.hermes-agent = hermes-agent.packages.${system}.default;
      packages.x86_64-linux.nixos-facter =
        nixos-facter.packages.${system}.nixos-facter or nixos-facter.packages.${system}.default;
      packages.x86_64-darwin.darwin-rebuild = darwinToolPkgs.darwin-rebuild;

      nixosConfigurations.anix = mkANixSystem "bare" installOptions.hostnames.anix;
      nixosConfigurations.apc = mkANixSystem "wsl" installOptions.hostnames.apc;

      darwinConfigurations.amac = nix-darwin.lib.darwinSystem {
        system = darwinSystem;

        specialArgs = mkSystemSpecialArgs {
          hostname = installOptions.hostnames.amac;
        };

        modules = [
          {
            nixpkgs.pkgs = darwinPkgs;
          }
        ]
        ++ mkHomeManagerModules {
          hmModule = home-manager.darwinModules.home-manager;
          userModule = ./darwin/home.nix;
        }
        ++ [ ./darwin/config.nix ];
      };
    };
}
