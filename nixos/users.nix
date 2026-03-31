/** Shared user and access configuration for the a.nix host variants. */
{ user, hostProfile, rootSshAuthorizedKeys, ... }: {
  users.users.${user} = {
    name = user;
    home = "/home/${user}";
    isNormalUser = true;

    extraGroups =
      if hostProfile == "bare" then [
        "dialout"
        "networkmanager"
        "wheel"
        "docker"
        "video"
        "audio"
        "seat"
        "libvirtd"
        "tty"
      ] else [
        "wheel"
        "docker"
      ];
  };

  users.users.root.openssh.authorizedKeys.keys = rootSshAuthorizedKeys;
}
