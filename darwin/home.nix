/** Home Manager configuration for the nix-darwin (a.mac) user environment. */
{ ... }: {
  imports = [
    ../home/common.nix
    ../home/features/1password-darwin.nix
  ];
}
