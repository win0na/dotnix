/**
  Shared nixpkgs config and overlays used across host package-set construction.
*/
{ inputs }:
{
  config.allowUnfree = true;

  overlays = [
    inputs.nix-vscode-extensions.overlays.default

    # point nix-adjacent tools at lix for consistency
    (final: prev: {
      inherit (prev.lixPackageSets.stable)
        nixpkgs-review
        nix-eval-jobs
        nix-fast-build
        ;
    })
  ];
}
