/** Shared Docker configuration for the anix host variants. */
{ ... }: {
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };
}
