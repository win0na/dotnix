/** Shared Docker configuration for the a.nix host variants. */
{ ... }: {
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };
}
