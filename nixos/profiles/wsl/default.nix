/**
  WSL profile for apc with Docker and WSLg support.

  This profile assumes mirrored networking is enabled from Windows via `.wslconfig`.
*/
{ user, hostname, ... }: {
  wsl = {
    enable = true;
    defaultUser = user;
    startMenuLaunchers = true;
    useWindowsDriver = true;

    interop.includePath = true;

    wslConf = {
      boot.systemd = true;

      automount = {
        enabled = true;
        root = "/mnt";
        mountFsTab = false;
        options = "metadata,umask=22,fmask=11";
      };
    };
  };
}
