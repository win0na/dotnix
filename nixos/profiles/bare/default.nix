/** Bare-metal wnix profile composed from desktop and hardware submodules. */
{ ... }: {
  imports = [
    ./boot.nix
    ./hardware.nix
    ./audio.nix
    ./desktop.nix
    ./gaming.nix
    ./peripherals.nix
    ./1password.nix
    ./virtualization.nix
    ./packages.nix
  ];
}
