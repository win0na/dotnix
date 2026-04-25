/**
  Bare-metal gaming stack, SteamOS integration, and game-streaming settings.
*/
{
  lib,
  pkgs,
  user,
  ...
}:
{
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

      environment = {
        STEAM_EXTRA_COMPAT_TOOLS_PATHS = lib.makeSearchPathOutput "steamcompattool" "" (
          with pkgs; [ proton-ge-bin ]
        );
        STEAM_MULTIPLE_XWAYLANDS = "1";
        ENABLE_GAMESCOPE_WSI = "1";
      };
    };

    steamos = {
      useSteamOSConfig = true;
      enableBluetoothConfig = true;
    };
  };

  services.sunshine = {
    enable = true;

    autoStart = false;
    capSysAdmin = true;
    openFirewall = true;
  };

  programs.steam = {
    protontricks.enable = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };

  environment.sessionVariables = {
    PROTON_ENABLE_AMD_AGS = "1";
    PROTON_ENABLE_NVAPI = "1";
    PROTON_USE_NTSYNC = "1";
    LD_LIBRARY_PATH = "/run/opengl-driver/lib:/run/opengl-driver-32/lib";
  };
}
