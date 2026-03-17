/** NixOS system configuration for the Linux (wnix) desktop and gaming host. */
{ config, lib, pkgs, self, inputs, user, hostname, ... }: {
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

  nixpkgs.config.permittedInsecurePackages = [
    "ventoy-1.1.07"
  ];


  boot = {
    extraModulePackages = [ config.boot.kernelPackages.evdi ];
    blacklistedKernelModules = [ "uvcvideo" ];
    consoleLogLevel = 3;

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

    kernelParams = [
      "quiet"
      "splash"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
      "random.trust_cpu=on"
      "video=DP-8:1920x1080R@60D"
    ];

    kernel.sysctl = {
      "kernel.split_lock_mitigate" = 0;
      "kernel.nmi_watchdog" = 0;
      "kernel.sched_bore" = "1";
    };

    initrd = {
      systemd.enable = true;
      verbose = false;
      
      availableKernelModules = [ "usbserial" ];
      kernelModules = [ "evdi" "uinput" ];
    };

    plymouth = {
      enable = true;
      theme = "cuts_alt";
      
      extraConfig = ''
        [Daemon]
        DeviceScale=2
        ShowDelay=1
      '';

      themePackages = with pkgs; [
        (adi1090x-plymouth-themes.override { selected_themes = [ "cuts_alt" ]; })
      ];
    };
  };

  hardware = {
    enableRedistributableFirmware = true;
    
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

    amdgpu.initrd.enable = false;

    bluetooth = {
      enable = true;
      powerOnBoot = true;

      input.General = {
        UserspaceHID = true;
        ClassicBondedOnly = false;
        IdleTimeout = 30;
      };

      settings = {
        General = {
          ControllerMode = "dual";
          DiscoverableTimeout = 0;
          FastConnectable = true;
          Experimental = true;
          KernelExperimental = lib.mkForce true;
        };

        Policy = {
          AutoEnable = true;
        };
      };
    };

    graphics = {
      enable = true;
      enable32Bit = true;
    };

    enableAllFirmware = true;
  };
  
  networking = {
    hostName = hostname;
    useDHCP = false;
    networkmanager.enable = true;
    
    firewall = {
      enable = false;

      allowedTCPPorts = [ 47984 47989 47990 48010 ];
      allowedUDPPorts = [ 9 ];
      allowedUDPPortRanges = [ { from = 47998; to = 48000; } ];
    };
  };

  users.defaultUserShell = pkgs.zsh;

  users.users.${user} = {
    name = user;
    home = "/home/${user}";
    isNormalUser = true;

    extraGroups = [
      "dialout"
      "networkmanager"
      "wheel"
      "docker"
      "video"
      "audio"
      "seat"
      "libvirtd"
      "tty"
    ];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClBpas/q9BP1YNEKQ1w7bHm2RjTJfIimOUWBHekHjoJ"
  ];

  jovian = {
    hardware.has.amd.gpu = true;

    decky-loader = {
      enable = false;
      user = user;

      extraPackages = with pkgs; [
        curl
        python3Minimal
        unzip
        wget
      ];
    };

    steam = {
      enable = true;

      user = user;
      desktopSession = "plasma";

      environment = {
        STEAM_EXTRA_COMPAT_TOOLS_PATHS = lib.makeSearchPathOutput "steamcompattool" "" (with pkgs; [ proton-ge-bin ]);
        STEAM_MULTIPLE_XWAYLANDS = "1";
        ENABLE_GAMESCOPE_WSI = "1";
      };
    };

    steamos = {
      useSteamOSConfig = true;
      enableBluetoothConfig = true;
    };
  };

  security = {
    rtkit.enable = true;
    polkit.enable = true;
  };

  services = {
    automatic-timezoned.enable = true;

    avahi.publish = {
      enable = true;
      userServices = true;
    };

    desktopManager.plasma6.enable = true;

    displayManager = {
      autoLogin = {
        enable = true;
        user = user;
      };

      defaultSession = "gamescope-wayland";

      sddm = {
        enable = true;
        enableHidpi = true;
        
        wayland = {
          enable = true;
          compositor = "kwin";
        };

        theme = "sddm-stray";
        
        extraPackages = with pkgs.kdePackages; [
          qtsvg
          qtmultimedia
        ]; 

        settings = {
          General = {
            DisplayServer = "wayland";
            GreeterEnvironment="QT_WAYLAND_SHELL_INTEGRATION=layer-shell,QT_SCREEN_SCALE_FACTORS=1.75,QT_FONT_DPI=192";
          };
        };
      };
    };
    
    flatpak = {
      enable = true;
      packages = [
        "io.edcd.EDMarketConnector"
        "org.mozilla.firefox"
      ];
    };

    haveged.enable = true;
    
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

      wireplumber = {
        enable = true;

        extraConfig = {
          "monitor.bluez.properties" = {
            "bluez5.enable-sbc-xq" = true;
            "bluez5.enable-msbc" = true;
          };
        };
      };
    };

    sunshine = {
      enable = true;

      autoStart = false;
      capSysAdmin = true;
      openFirewall = true;
    };

    solaar = {
      enable = true;
      extraArgs = "--restart-on-wake-up";
    };

    udev.extraRules = ''
      # dualsense usb & bt hidraw
      KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0660", TAG+="uaccess"
      KERNEL=="hidraw*", KERNELS=="*054C:0CE6*", MODE="0660", TAG+="uaccess"

      # dualense edge usb & bt hidraw
      KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0df2", MODE="0660", TAG+="uaccess"
      KERNEL=="hidraw*", KERNELS=="*054C:0DF2*", MODE="0660", TAG+="uaccess"

      ACTION!="remove", SUBSYSTEMS=="usb", ATTRS{idVendor}=="19f5", ATTRS{idProduct}=="1028", MODE="0660", TAG+="uaccess"
    '';

    seatd.enable = true;
    thermald.enable = true;
  };

  systemd = {
    services = {
      bluetooth = {
        overrideStrategy = "asDropin";

        serviceConfig = {
          ExecStartPost = "/bin/sh -c '${pkgs.coreutils}/bin/sleep 3; rfkill unblock bluetooth; ${pkgs.bluez}/bin/bluetoothctl power on'";
          ExecStart = lib.mkForce "\nExecStart=${pkgs.bluez}/libexec/bluetooth/bluetoothd --experimental -p input";
        };
      };

      plymouth-quit = {
        overrideStrategy = "asDropin";

        serviceConfig = {
          ExecStartPre = " ${pkgs.coreutils}/bin/sleep 4";
        };
      };
      
    };

    settings.Manager = {
      DefaultTimeoutStopSec = "5s";
    };
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

    steam = {
      protontricks.enable = true;
      extraCompatPackages = with pkgs; [ proton-ge-bin ];
    };
    
    tmux.enable = true;
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
    etc = {
      "1password/custom_allowed_browsers" = {
        text = ''
          zen
        '';

        mode = "0755";
      };
    };

    sessionVariables = {
      PROTON_ENABLE_AMD_AGS = "1";
      PROTON_ENABLE_NVAPI = "1";
      PROTON_USE_NTSYNC = "1";
      LD_LIBRARY_PATH="/run/opengl-driver/lib:/run/opengl-driver-32/lib";
    };

    systemPackages = with pkgs; [
      darktable
      dualsensectl
      geekbench
      jq
      libayatana-appindicator

      (limo.override {
        withUnrar = true;
      })

      (lutris.override {
        extraLibraries =  pkgs: [ ];
      })

      msr-tools
      nurl
      ocs-url
      pciutils
      plex-desktop
      plex-htpc
      pulseaudio
      prismlauncher
      python312Packages.pip
      s-tui
      ungoogled-chromium
      unrar
      usbutils
      winetricks
      wineWowPackages.stable
      e2fsprogs
      wlr-randr
      wmctrl
      unzip
      via
      ventoy-full

      kdePackages.qttools

      inputs.sddm-stray.packages.${pkgs.system}.default
      inputs.kwin-effects-forceblur.packages.${pkgs.system}.default
      inputs.librepods.packages.${pkgs.system}.default
      inputs.inputactions.packages.${pkgs.system}.inputactions-ctl
      inputs.inputactions.packages.${pkgs.system}.inputactions-kwin

      (makeAutostartItem {
        name = "1password";
        package = _1password-gui;
      })

      (sddm-astronaut.override {
        embeddedTheme = "black_hole";
      })
    ];
  };
}
