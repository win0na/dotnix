/**
  WSL networking stack using NixOS-WSL generated guest network config.

  Mirrored networking itself is configured on the Windows host via `%UserProfile%\.wslconfig`
  (`[wsl2] networkingMode=mirrored`), not from inside the WSL guest. This module only
  manages guest-side hostname and hosts/resolver generation.
*/
{ hostname, ... }: {
  networking = {
    hostName = hostname;
    networkmanager.enable = false;
    useDHCP = false;
    firewall.enable = false;
  };

  wsl.wslConf.network = {
    hostname = hostname;
    generateHosts = true;
    generateResolvConf = true;
  };
}
