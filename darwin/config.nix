/** nix-darwin system configuration for the macOS (amac) build server host. */
{ config, lib, pkgs, self, inputs, user, hostname, ... }: let
  # 1x1 solid #282828 png for the gruvbox background
  gruvboxWallpaper = ./gruvbox.png;
in {
  imports = [ ../common/system.nix ];

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
      "win0na/tap/macdefaultbrowser"
    ];

    casks = [
      "1password"
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
    # make nix, homebrew, and system binaries visible
    export PATH="/run/current-system/sw/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/usr/sbin:$PATH"

    # report missing non-declarative tooling instead of installing it during activation
    if ! xcodebuild -version &>/dev/null; then
      echo -e "\n\e[0m\e[1manix: no working xcode found; install xcode before using xcode-dependent workflows\e[0m"
    fi

    if ! command -v supergateway &>/dev/null; then
      echo -e "\n\e[0m\e[1manix: supergateway is not installed; install it manually if you still need it\e[0m"
    fi

    # set brave as the default browser
    sudo -u ${user} macdefaultbrowser com.brave.Browser || true

    # install wallpaper to a persistent location and apply it
    cp -f ${gruvboxWallpaper} /Library/Desktop\ Pictures/gruvbox.png || true

    # set desktop wallpaper on all screens via desktoppr
    sudo -u ${user} desktoppr "/Library/Desktop Pictures/gruvbox.png" || true

    # set lockscreen wallpaper for all users
    for uuid_dir in /Library/Caches/Desktop\ Pictures/*/; do
      cp -f ${gruvboxWallpaper} "$uuid_dir/lockscreen.png" 2>/dev/null || true
    done

    # reset dock icons one last time
    killall Dock || true

    echo -e "\n\e[0m\e[1manix: run 'mas upgrade' sometimes to update app store apps\e[0m"
  '';

  # keep the display awake with caffeinate
  launchd.daemons.caffeinate = {
    serviceConfig = {
      ProgramArguments = [ "/usr/bin/caffeinate" "-d" "-i" "-s" ];
      KeepAlive = true;
      RunAtLoad = true;
    };
  };

  launchd.daemons.ollama = {
    serviceConfig = {
      ProgramArguments = [ "${pkgs.ollama}/bin/ollama" "serve" ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/var/log/ollama.log";
      StandardErrorPath = "/var/log/ollama.log";
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
