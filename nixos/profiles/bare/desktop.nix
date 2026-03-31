/** Bare-metal desktop session, display manager, and GUI services. */
{ pkgs, user, ... }: {
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

        settings.General = {
          DisplayServer = "wayland";
          GreeterEnvironment = "QT_WAYLAND_SHELL_INTEGRATION=layer-shell,QT_SCREEN_SCALE_FACTORS=1.75,QT_FONT_DPI=192";
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
    seatd.enable = true;
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
  };
}
