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
      "twardoch/tap/macdefaultbrowser"
      "xcodes"
      "xcodegen"
      "getsentry/xcodebuildmcp/xcodebuildmcp"
    ];

    casks = [
      "brave-browser"
      "desktoppr"
      "gswitch"
      "macs-fan-control"
    ];

    masApps = {
      "1Password for Safari" = 1569813296;
    };
  };

  environment.systemPackages = with pkgs; [
    grandperspective
  ];

  system.activationScripts.postActivation.text = ''
    # ensure all binaries are visible: nix profile, homebrew, and system paths
    export PATH="/run/current-system/sw/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/usr/sbin:$PATH"

    # install the latest xcode if no working xcode is found
    if ! xcodebuild -version &>/dev/null; then
      echo -e "\n\e[0m\e[1mdotnix: no working xcode found, installing xcode...\e[0m"
      xcodes install --latest --experimental-unxip
    fi

    # install supergateway globally if not already installed
    if ! command -v supergateway &>/dev/null; then
      echo -e "\n\e[0m\e[1mdotnix: installing supergateway globally via npm...\e[0m"
      npm install -g supergateway
    fi

    # set brave as the default browser
    sudo -u ${user} macdefaultbrowser com.brave.Browser

    # install wallpaper to a persistent location and apply it
    cp -f ${gruvboxWallpaper} /Library/Desktop\ Pictures/gruvbox.png

    # set desktop wallpaper on all screens via desktoppr
    sudo -u ${user} desktoppr "/Library/Desktop Pictures/gruvbox.png"

    # set lockscreen wallpaper for all users
    for uuid_dir in /Library/Caches/Desktop\ Pictures/*/; do
      cp -f ${gruvboxWallpaper} "$uuid_dir/lockscreen.png" 2>/dev/null || true
    done

    # reset dock icons one final time
    killall Dock

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
