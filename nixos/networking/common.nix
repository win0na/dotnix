/** Networking settings shared by both bare and WSL anix profiles. */
{ hostname, ... }: {
  networking.hostName = hostname;
}
