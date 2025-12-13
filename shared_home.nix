{ pkgs, lib, inputs, user, email, ... }: {
  imports = [
    inputs.zen-browser.homeModules.twilight
  ];

  home.stateVersion = "23.05";

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  xdg.mimeApps = let
    value = let
      zen-browser = inputs.zen-browser.packages.${builtins.currentSystem}.twilight;
    in
      zen-browser.meta.desktopFileName;

    associations = builtins.listToAttrs (map (name: {
      inherit name value;
    }) [
      "application/x-extension-shtml"
      "application/x-extension-xhtml"
      "application/x-extension-html"
      "application/x-extension-xht"
      "application/x-extension-htm"
      "x-scheme-handler/unknown"
      "x-scheme-handler/mailto"
      "x-scheme-handler/chrome"
      "x-scheme-handler/about"
      "x-scheme-handler/https"
      "x-scheme-handler/http"
      "application/xhtml+xml"
      "application/json"
      "text/plain"
      "text/html"
    ]);
  in {
    associations.added = associations;
    defaultApplications = associations;
  };

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;

      userName = user;
      userEmail = email;
      ignores = [ "._*" ];

      extraConfig = {
        init.defaultBranch = "main";
        push.autoSetupRemote = true;

        gpg = {
          format = "ssh";
        };

        "gpg \"ssh\"" = {
          program =
            if
              pkgs.stdenv.isDarwin
            then
              "${pkgs._1password-gui}/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
            else
              "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
        };

        commit = {
          gpgsign = true;
        };

        user = {
          signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClBpas/q9BP1YNEKQ1w7bHm2RjTJfIimOUWBHekHjoJ";
        };
      };
    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;

      matchBlocks."*" = {
        identityAgent =
          if
            pkgs.stdenv.isLinux
          then
            "~/.1password/agent.sock"
          else
            "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
      };
    };

    vscode = {
      enable = true;
      package = pkgs.vscodium;

      profiles.default.extensions = with pkgs.vscode-marketplace; [
        bbenoist.nix
      ];
    };

    zen-browser = {
      enable = true;

      policies = {
        AutofillAddressEnabled = false;
        AutofillCreditCardEnabled = false;
        DisableAppUpdate = true;
        DisableFeedbackCommands = true;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableTelemetry = true;
        DontCheckDefaultBrowser = true;
        NoDefaultBookmarks = true;
        OfferToSaveLogins = false;
        PasswordManagerEnabled = false;
        SearchSuggestEnabled = true;

        SearchEngines = {
          Add = [
            {
              Name = "Brave Search";
              URLTemplate = "https://search.brave.com/search?q={searchTerms}";
              SuggestURLTemplate = "https://search.brave.com/api/suggest?q={searchTerms}";
            }
          ];

          Default = "Brave Search";
        };

        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };
      };
      
      profiles.default = {
        isDefault = true;

        userChrome = ''
          .zen-current-workspace-indicator,
          .pinned-tabs-container-separator {
            display: none !important;
          }
        '';

        settings = {
          "devtools.debugger.remote-enabled" = true;
          "devtools.chrome.enabled" = true;
          "browser.shell.checkDefaultBrowser" = false;
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          "zen.tabs.show-newtab-vertical" = true;
          "zen.theme.accent-color" = "#8aadf4";
          "zen.urlbar.behavior" = "float";
          "zen.view.show-newtab-button-top" = false;
          "zen.view.use-single-toolbar" = false;
          "zen.view.window.scheme" = 0;
          "zen.welcome-screen.seen" = true;
          "zen.workspaces.continue-where-left-off" = true;
        };
      };
    };

    zsh = {
      enable = true;

      shellAliases = {
        sw = "sudo ${if pkgs.stdenv.isDarwin then "darwin" else "nixos"}-rebuild switch --flake $HOME/$HOST";
        vim = "nvim";
      };
    };
  };
}