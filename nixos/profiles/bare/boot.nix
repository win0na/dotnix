/** Bare-metal boot, kernel, and initrd configuration. */
{ config, pkgs, ... }: {
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

  systemd.services.plymouth-quit = {
    overrideStrategy = "asDropin";

    serviceConfig = {
      ExecStartPre = " ${pkgs.coreutils}/bin/sleep 4";
    };
  };
}
