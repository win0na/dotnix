/** Home Manager configuration for the NixOS (wnix) user environment. */
{ pkgs, lib, inputs, user, email, ... }: {
  imports = [
    ../shared_home.nix
    inputs.zen-browser.homeModules.twilight
  ];
  

  home.file.".config/kwalletrc".text = ''
    [Wallet]
    Enabled=false
  '';

  dconf = {
    enable = true;

    settings = {
      "org/gnome/desktop/interface".color-scheme = "prefer-dark";
      "org/gnome/desktop/peripherals/touchpad".scroll-factor = 0.5;
    };
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
    zen-browser = {
      enable = true;

      policies = let
        mkExtensionSettings = builtins.mapAttrs (_: pluginId: {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/${pluginId}/latest.xpi";
          installation_mode = "force_installed";
        });
      in {
        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };

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
              Alias = "@b";
              URLTemplate = "https://search.brave.com/search?q={searchTerms}";
              SuggestURLTemplate = "https://search.brave.com/api/suggest?q={searchTerms}";
            }
          ];

          Default = "Google";
        };

        ExtensionSettings = mkExtensionSettings {
          "{d634138d-c276-4fc8-924b-40a0ea21d284}" = "1password-x-password-manager";
          "uBlock0@raymondhill.net" = "ublock-origin";
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
          "browser.urlbar.showSearchSuggestionsFirst" = false;
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          "zen.tabs.show-newtab-vertical" = true;
          "zen.theme.accent-color" = "#8aadf4";
          "zen.urlbar.behavior" = "floating-on-type";
          "zen.view.show-newtab-button-top" = false;
          "zen.view.use-single-toolbar" = false;
          "zen.view.window.scheme" = 0;
          "zen.welcome-screen.seen" = true;
          "zen.widget.linux.transparency" = true;
          "zen.workspaces.continue-where-left-off" = true;
        };
      };
    };
  };
}
