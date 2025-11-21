{ config, lib, pkgs, self, inputs, user, ... }: {
  imports = [ ../shared_config.nix ];

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 4;

  # we use determinate nix on darwin systems, for now
  nix.enable = false;

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
      "qemu"
    ];

    casks = [
      "gswitch"
      "macs-fan-control"
      "plex"
    ];

    masApps = {
      "1Password for Safari" = 1569813296;
      "Photomator – Photo Editor" = 1444636541;
    };
  };

  system.activationScripts.postActivation.text = ''
    # reset dock icons one final time
    killall Dock

    echo -e "\nDon't forget to upgrade your mas apps periodically using 'mas upgrade'!\n"
  '';

  system.defaults = {
    dock = {
      persistent-apps = [
        {
          app = "/Applications/Nix Apps/Brave Browser.app";
        }
        {
          app = "/System/Applications/Messages.app";
        }
        {
          app = "/System/Applications/Mail.app";
        }
        {
          app = "/System/Applications/Music.app";
        }
        {
          app = "/Applications/Photos.app";
        }
        {
          app = "/Users/winona/Applications/Home Manager Apps/Visual Studio Code.app";
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
        "/Users/winona/Downloads"
      ];
    };
  };
}