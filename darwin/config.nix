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
      "zen"
    ];

    masApps = {
      "1Password for Safari" = 1569813296;
      "Photomator – Photo Editor" = 1444636541;
    };
  };

  environment.systemPackages = with pkgs; [
    grandperspective
  ];


  system.activationScripts.postActivation.text = ''
    # reset dock icons one final time
    killall Dock

    echo -e "\n\e[0m\e[1mdotnix: periodically upgrade your mas apps using 'mas upgrade'\e[0m"
  '';

  system.defaults = {
    dock = {
      persistent-apps = [
        {
          app = "/Applications/Safari.app";
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
          app = "/System/Applications/Photos.app";
        }
        {
          app = "/Users/${user}/Applications/Home Manager Apps/VSCodium.app";
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