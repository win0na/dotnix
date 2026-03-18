/** nix-darwin system configuration for the macOS (wmac) build server host. */
{ config, lib, pkgs, self, inputs, user, hostname, ... }: let
  # 1x1 solid #282828 png (gruvbox dark background)
  gruvboxWallpaper = ./gruvbox.png;
in {
  imports = [ ../shared_config.nix ];

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 6;

  networking.hostName = hostname;
  networking.computerName = hostname;

  users.users.${user} = {
    name = user;
    home = "/Users/${user}";
    shell = pkgs.zsh;
  };

  system.primaryUser = user;

  programs = {
    _1password.enable = true;
    _1password-gui.enable = true;

    zsh.enable = true;
  };

  homebrew = {
    enable = true;
    onActivation.cleanup = "uninstall";

    brews = [
      "go"
      "mas"
      "node"
      "qemu"
      "xcodes"
      "xcodegen"
      "getsentry/xcodebuildmcp/xcodebuildmcp"
    ];

    casks = [
      "brave-browser"
      "gswitch"
      "macs-fan-control"
      "zen"
    ];

    masApps = {
      "1Password for Safari" = 1569813296;
    };
  };

  environment.systemPackages = with pkgs; [
    defaultbrowser
    grandperspective
  ];

  system.activationScripts.postActivation.text = ''
    # ensure homebrew binaries are available during activation
    export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

    # install the latest xcode if no working xcode is found
    if ! xcodebuild -version &>/dev/null; then
      echo -e "\n\e[0m\e[1mdotnix: no working xcode found, installing xcode 26...\e[0m"
      xcodes install --latest --experimental-unxip
    fi

    # install supergateway globally if not already installed
    if ! command -v supergateway &>/dev/null; then
      echo -e "\n\e[0m\e[1mdotnix: installing supergateway globally via npm...\e[0m"
      npm install -g supergateway
    fi

    # set lockscreen to gruvbox dark background (#282828)
    defaults write /Library/Caches/com.apple.desktop.admin desktopLockScreenImage "${gruvboxWallpaper}"

    # reset dock icons one final time
    killall Dock

    # set brave as the default browser (runs as user since defaultbrowser needs user context)
    sudo -u ${user} defaultbrowser brave

    # set wallpaper to gruvbox dark background (#282828) on all screens
    sudo -u ${user} osascript -e 'tell application "Finder" to set desktop picture to POSIX file "${gruvboxWallpaper}"'

    echo -e "\n\e[0m\e[1mdotnix: periodically upgrade your mas apps using 'mas upgrade'\e[0m"
  '';

  # keep display always on using caffeinate
  launchd.daemons.caffeinate = {
    serviceConfig = {
      ProgramArguments = [ "/usr/bin/caffeinate" "-d" "-i" "-s" ];
      KeepAlive = true;
      RunAtLoad = true;
    };
  };

  system.defaults = {
    dock = {
      persistent-apps = [
        {
          app = "/Applications/Brave Browser.app";
        }
        {
          app = "/System/Applications/Messages.app";
        }
        {
          app = "/Users/${user}/Applications/Home Manager Apps/Visual Studio Code.app";
        }
        {
          app = "/System/Applications/Utilities/Terminal.app";
        }
        {
          app = "/System/Applications/Utilities/Activity Monitor.app";
        }
        {
          app = "/System/Applications/System Settings.app";
        }
      ];

      show-recents = false;

      persistent-others = [
        "/Users/${user}/Downloads"
      ];
    };
  };
}
