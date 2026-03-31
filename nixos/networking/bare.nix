/** Bare-metal networking stack using NetworkManager. */
{ ... }: {
  networking = {
    useDHCP = false;
    networkmanager.enable = true;
  };
}
