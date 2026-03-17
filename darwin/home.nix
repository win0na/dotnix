/** Home Manager configuration for the nix-darwin (wmac) user environment. */
{ pkgs, lib, inputs, user, email, ... }: {
  imports = [ ../shared_home.nix ];
}