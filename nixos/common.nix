/** Shared NixOS settings for both bare and WSL anix profiles. */
{ pkgs, self, ... }: {
  imports = [
    ./features/allynx.nix
  ];

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = "25.11";

  users.defaultUserShell = pkgs.zsh;

  services.openssh.enable = true;

  services.ollama = {
    enable = true;
  };

  programs = {
    _1password.enable = true;
    tmux.enable = true;
    zsh.enable = true;
  };

  environment.systemPackages = with pkgs; [
    jq
    nurl
    python312Packages.pip
    unzip
    e2fsprogs
    pciutils
    usbutils
  ];
}
