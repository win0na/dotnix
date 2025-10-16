{ self, pkgs, ... }: {
  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = "25.11";

  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    nix-vscode-extensions.overlays.default
  ];

  boot.loader = {
    efi.efiSysMountPoint = "/boot";
    systemd-boot.enable = true;
  };

  # unable to distribute wifi/bt firmware, download & extract from apple yourself into ./firmware
  hardware.firmware = [
    (pkgs.stdenvNoCC.mkDerivation (final: {
      name = "brcm-firmware";
      src = ./firmware/brcm;
      installPhase = ''
        mkdir -p $out/lib/firmware/brcm
        cp ${final.src}/* "$out/lib/firmware/brcm"
      '';
    }))
  ];

  networking.networkmanager.enable = true;

  users.users.${user} = {
    name = user;
    home = "/home/${user}";
    extraGroups = [ "wheel" ];
  };

  system.primaryUser = user;

  services = {
    openssh.enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };

  environment.gnome.excludePackages = with pkgs; [
    yelp
  ];

  environment.systemPackages = with pkgs; [
    curl fastfetch git neovim wezterm wget
  ];
}