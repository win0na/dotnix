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

  environment.systemPackages = with pkgs; [
    curl brave fastfetch git neovim qbittorrent wget vuetorrent
  ];
}