/** Shared system configuration applied to both NixOS and nix-darwin hosts. */
{ pkgs, inputs, ... }: {
  nixpkgs = {
    config.allowUnfree = true;

    overlays = [
      inputs.nix-vscode-extensions.overlays.default

      # rewire nix-adjacent tooling to use lix for consistency
      (final: prev: {
        inherit (prev.lixPackageSets.stable)
          nixpkgs-review
          nix-eval-jobs
          nix-fast-build;
      })
    ];
  };

  # use lix as the system nix implementation
  nix.package = pkgs.lixPackageSets.stable.lix;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    warn-dirty = false; # this "feature" is an eyesore
  };

  environment.systemPackages = with pkgs; [
    curl fastfetch git neovim qbittorrent wget vuetorrent
  ];
}
