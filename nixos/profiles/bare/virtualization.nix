/** Bare-metal virtualization beyond the shared Docker configuration. */
{ ... }: {
  virtualisation.libvirtd.enable = true;
}
