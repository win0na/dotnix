{ pkgs, self, inputs, user, ... }: let
  self.session_select = pkgs.writeShellScriptBin "steamos-session-select" ''
    steam -shutdown
  '';
in {
  imports = [ ../shared_config.nix ];

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = "25.11";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    inputs.nix-vscode-extensions.overlays.default
  ];

  boot = {
    blacklistedKernelModules = [ "uvcvideo" ];

    loader = {
      efi.efiSysMountPoint = "/boot";
      systemd-boot.enable = true;
    };
  };

  hardware = {
    firmware = [
      (pkgs.stdenvNoCC.mkDerivation (final: {
        name = "brcm-firmware";
        src = ./firmware/brcm;
        installPhase = ''
          mkdir -p $out/lib/firmware/brcm
          cp ${final.src}/* "$out/lib/firmware/brcm"
        '';
      }))
    ];
    
    bluetooth.enable = true;

    graphics = {
        enable = true;
        enable32Bit = true;
    };
  };
  
  networking = {
    hostName = "wmac";
    networkmanager.enable = true;
  };

  users.defaultUserShell = pkgs.zsh;

  users.users.${user} = {
    name = user;
    home = "/home/${user}";
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  services = {
    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
      };

      sessionPackages = [
        (pkgs.gamescope.overrideAttrs
          (postAttrs: rec {
            postInstall =
              let session = ''
                [Desktop Entry]
                Name=Steam (GameScope)
                Comment=Dynamic Wayland compositor
                Exec=${pkgs.gamescope}/bin/gamescope -e -f -F fsr --mangoapp --cursor-scale-height 960 --adaptive-sync -- steam -tenfoot -steamos3
                Type=Application
              '';
              in ''
                mkdir -p $out/share/wayland-sessions
                echo "${session}" >> $out/share/wayland-sessions/steam.desktop
              '';
            passthru.providedSessions = [ "steam" ];
          })
        )
      ];
    };

    desktopManager.plasma6.enable = true;
    
    openssh = {
      enable = true;
    };

    thermald.enable = true;
    qbittorrent.enable = true;
  };

  programs = {
    gamescope = {
      enable = true;
      capSysNice = true;
    };
    
    steam = {
      enable = true;

      gamescopeSession.enable = true;
      extraCompatPackages = with pkgs; [ proton-ge-bin ];
    };

    zsh.enable = true;
    _1password.enable = true;

    _1password-gui = {
      enable = true;
      polkitPolicyOwners = [ user ];
    };
  };

  environment.systemPackages = with pkgs; [
    jq
    prismlauncher
    self.session_select
    toybox
    wget
  ];
}
