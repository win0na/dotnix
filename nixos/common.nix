/**
  Shared NixOS settings for both bare and WSL anix profiles.
*/
{ pkgs, self, user, ... }:
let
  homeDirectory = "/home/${user}";
  hermesSettings = import ../home/features/hermes/config.nix {
    inherit homeDirectory;
  };
in
{
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

  services.hermes-agent = {
    enable = true;
    user = user;
    group = "users";
    createUser = false;
    stateDir = homeDirectory;
    workingDirectory = homeDirectory;
    addToSystemPackages = true;
    restart = "on-failure";
    restartSec = 5;
    settings = hermesSettings;
  };

  programs = {
    _1password.enable = true;
    nix-ld.enable = true;
    tmux.enable = true;
    zsh.enable = true;
  };

  environment.systemPackages = with pkgs; [
    jq
    nurl
    unzip
    e2fsprogs
    pciutils
    usbutils
  ];
}
