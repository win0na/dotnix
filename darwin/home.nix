/**
  Home Manager configuration for the nix-darwin (amac) user environment.
*/
{ ... }:
{
  imports = [
    ../home/common.nix
    ../home/features/api-keys.nix
    ../home/features/hermes/darwin.nix
    ../home/features/1password-darwin.nix
  ];
}
