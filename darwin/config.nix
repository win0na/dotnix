{ pkgs, self, user, inputs, ... }: {
  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 4;

  nix.enable = false;
  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    inputs.nix-vscode-extensions.overlays.default
  ];

  system.activationScripts.postActivation.text = ''
    # Force reload of preference cache to apply trackpad settings
    killall cfprefsd 2>/dev/null || true
    killall Dock
  '';

  users.defaultUserShell = pkgs.zsh;

  users.users.${user} = {
    name = user;
    home = "/Users/${user}";
  };

  system.primaryUser = user;

  programs = {
    zsh.enable = true;
    _1password.enable = true;

    _1password-gui = {
      enable = true;
      polkitPolicyOwners = [ user ];
    };
  };

  environment.systemPackages = with pkgs; [
    curl fastfetch git neovim wget
  ];

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
    };
  };

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