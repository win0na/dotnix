/** Shared user and access configuration for the wnix host. */
{ user, wnixMode, ... }: {
  users.users.${user} = {
    name = user;
    home = "/home/${user}";
    isNormalUser = true;

    extraGroups =
      if wnixMode == "bare" then [
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

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClBpas/q9BP1YNEKQ1w7bHm2RjTJfIimOUWBHekHjoJ"
  ];
}
