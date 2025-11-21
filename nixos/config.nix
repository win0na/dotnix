{ config, lib, pkgs, self, inputs, user, ... }: let
  self = with pkgs; {
    autostart_1pass = makeAutostartItem {
      name = "1password";
      package = _1password-gui;
    };
  };
in {
  imports = [ ../shared_config.nix ];

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = "25.11";

  nixpkgs.overlays = [
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
      timeout = 0;

      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };

      systemd-boot = {
        enable = true;
        consoleMode = "max";
        configurationLimit = 5;
      };
    };

    kernelParams = [ "quiet" ];

    kernel.sysctl = {
      "kernel.split_lock_mitigate" = 0;
      "kernel.nmi_watchdog" = 0;
      "kernel.sched_bore" = "1";
    };

    initrd = {
      systemd.enable = true;
      kernelModules = [ ];
      verbose = false;
    };

    plymouth.enable = true;
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
    
    
    bluetooth = {
      enable = true;

      settings = {
        General = {
          MultiProfile = "multiple";
          FastConnectable = true;
        };
      };
    };

    amdgpu.initrd.enable = false;

    graphics = {
        enable = true;
        enable32Bit = true;
    };

    enableAllFirmware = true;
  };
  
  networking = {
    hostName = "wmac";
    networkmanager.enable = true;
    firewall.enable = false;
  };

  users.defaultUserShell = pkgs.zsh;

  users.users.${user} = {
    name = user;
    home = "/home/${user}";
    isNormalUser = true;

    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "video"
      "audio"
      "seat"
      "libvirtd"
    ];
  };

  jovian = {
    steam = {
      enable = true;

      autoStart = true;
      user = user;
      desktopSession = "plasma";
    };

    hardware.has.amd.gpu = true;
    decky-loader.enable = true;
    steamos.useSteamOSConfig = true;
  };

  security = {
    rtkit.enable = true;
    polkit.enable = true;
  };

  services = {
    automatic-timezoned.enable = true;
    desktopManager.plasma6.enable = true;
    
    flatpak = {
      enable = true;
      packages = [ "io.edcd.EDMarketConnector" ];
    };
    
    openssh = {
      enable = true;
    };

    pipewire = {
      enable = true;
      pulse.enable = true;

      alsa = {
        enable = true;
        support32Bit = true;
      };
    };

    seatd.enable = true;
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

    xserver.enable = false;
  };

  systemd.settings.Manager = {
    DefaultTimeoutStopSec = "5s";
  };

  programs = {
    _1password.enable = true;

    _1password-gui = {
      enable = true;
      polkitPolicyOwners = [ user ];
    };

    appimage = {
      enable = true;
      binfmt = true;
    };

    zsh.enable = true;
  };

  virtualisation = {
    docker = {
      enable = true;
      enableOnBoot = false;
    };

    libvirtd.enable = true;
  };

  environment = {
    sessionVariables = {
      PROTON_ENABLE_AMD_AGS = "1";
      PROTON_ENABLE_NVAPI = "1";
      PROTON_USE_NTSYNC = "1";

      ENABLE_GAMESCOPE_WSI = "1";
      ENABLE_HDR_WSI = "1";

      DXVK_HDR = "1";
      SYEAM_MULTIPLE_XWAYLANDS = "1";
    };

    systemPackages = with pkgs; [
      jq
      keyd
      prismlauncher
      toybox

      self.autostart_1pass
    ];
  };
}
