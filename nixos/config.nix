{ config, lib, pkgs, self, inputs, user, ... }: let
  self = with pkgs; {
    session_select = writeShellScriptBin "steamos-session-select" ''
      steam -shutdown
    '';

    autostart_1pass = makeAutostartItem {
      name = "1password";
      package = _1password-gui;
    };
  };
in {
  imports = [ ../shared_config.nix ];

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = "25.11";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    inputs.nix-vscode-extensions.overlays.default

    (final: prev: {
      _1password-gui = prev._1password-gui.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          substituteInPlace $out/share/applications/1password.desktop \
            --replace "Exec=1password" "Exec=1password --silent"
        '';
      });
    })
  ];

  boot = {
    blacklistedKernelModules = [ "uvcvideo" ];

    loader = {
      efi.efiSysMountPoint = "/boot";
      timeout = 0;

      systemd-boot = {
        enable = true;
        consoleMode = "max";
        configurationLimit = 5;
      };
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

    apple.touchBar = {
      enable = true;

      settings = {
        MediaLayerDefault = true;
        AdaptiveBrightness = true;
      };
    };
    
    bluetooth.enable = true;

    graphics = {
        enable = true;
        enable32Bit = true;
    };

    enableAllFirmware = true;
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

  security.rtkit.enable = true;

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
    
    flatpak = {
      enable = true;
      packages = [ "io.edcd.EDMarketConnector" ];
    };
    
    openssh = {
      enable = true;
    };

    pulseaudio.enable = false;

    pipewire = {
      enable = true;
      pulse.enable = true;

      alsa = {
        enable = true;
        support32Bit = true;
      };
    };

    thermald.enable = true;

    t2fanrd = {
      enable = true;

      config = {
        Fan1 = {
          low_temp = 40;
          high_temp = 70;
          speed_curve = "linear";
          always_full_speed = false;
        };

        Fan2 = {
          low_temp = 40;
          high_temp = 70;
          speed_curve = "linear";
          always_full_speed = false;
        };
      };
    };

    qbittorrent.enable = true;
  };

  systemd.user.services.pipewire.environment = {
    LADSPA_PATH = "${pkgs.ladspaPlugins}/lib/ladspa";
    LV2_PATH = lib.mkForce "${config.system.path}/lib/lv2";
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
    keyd
    prismlauncher
    toybox

    calf
    ladspaPlugins
    lsp-plugins

    self.autostart_1pass
    self.session_select
  ];
}
