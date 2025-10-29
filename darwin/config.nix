{ pkgs, self, user, inputs, ... }: {
  imports = [ ../shared_config.nix ];

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 4;

  nix.enable = false;
  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    inputs.nix-vscode-extensions.overlays.default
  ];

  users.users.${user} = {
    name = user;
    home = "/Users/${user}";
    shell = pkgs.zsh;
  };

  system.primaryUser = user;

  programs = {
    zsh.enable = true;

    _1password.enable = true;
    _1password-gui.enable = true;
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
          app = "/Applications/Photomator.app";
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