/** System configuration shared by the NixOS and nix-darwin hosts. */
{ pkgs, inputs, ... }: {
  nixpkgs = {
    config.allowUnfree = true;

    overlays = [
      inputs.nix-vscode-extensions.overlays.default

      # point nix-adjacent tools at lix for consistency
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
    warn-dirty = false; # keep dirty-tree warnings off
  };

  environment.systemPackages = with pkgs; [
    bun
    curl
    fastfetch
    git
    neovim
    nixd
    ollama
    qbittorrent
    wget
  ];
}
