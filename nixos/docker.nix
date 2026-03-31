/** Shared Docker configuration for the wnix host. */
{ ... }: {
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };
}
