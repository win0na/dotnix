/**
  Shared nixpkgs policy for Linux hosts that rely on module-driven package-set construction.
*/
{ inputs, ... }:
{
  nixpkgs = import ./nixpkgs-policy.nix { inherit inputs; };
}
