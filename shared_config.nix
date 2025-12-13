{ pkgs, inputs, ... }: {
  nixpkgs = {
    config.allowUnfree = true;

    overlays = [
      inputs.nix-vscode-extensions.overlays.default
    ];
  };
  
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    warn-dirty = false; # this "feature" is an eyesore
  };

  environment.etc = {
    "1password/custom_allowed_browsers" = {
      text = ''
        zen-twilight
      '';

      mode = "0755";
    };
  };

  environment.systemPackages = with pkgs; [
    curl fastfetch firefoxpwa git neovim qbittorrent wget vuetorrent
  ];
}