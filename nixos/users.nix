/** Shared user and access configuration for the anix host variants. */
{ user, hostProfile, sshAuthorizedKeys, ... }: {
  users.users.${user} = {
    name = user;
    home = "/home/${user}";
    isNormalUser = true;
    openssh.authorizedKeys.keys = sshAuthorizedKeys;

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

  users.users.root.openssh.authorizedKeys.keys = sshAuthorizedKeys;
}
