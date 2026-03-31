/** Networking settings shared by both bare and WSL a.nix profiles. */
{ hostname, ... }: {
  networking.hostName = hostname;
}
