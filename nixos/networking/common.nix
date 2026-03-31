/** Networking settings shared by both bare and WSL wnix profiles. */
{ hostname, ... }: {
  networking.hostName = hostname;
}
