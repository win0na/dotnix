/**
  Bare-metal desktop, gaming, and hardware-oriented packages.
*/
{ pkgs, inputs, ... }:
{
  nixpkgs.config.permittedInsecurePackages = [
    "ventoy-1.1.07"
  ];

  environment.systemPackages = with pkgs; [
    darktable
    dualsensectl
    geekbench
    libayatana-appindicator

    (limo.override {
      withUnrar = true;
    })

    (lutris.override {
      extraLibraries = pkgs: [ ];
    })

    msr-tools
    ocs-url
    plex-desktop
    plex-htpc
    pulseaudio
    prismlauncher
    s-tui
    ungoogled-chromium
    unrar
    winetricks
    wineWowPackages.stable
    wlr-randr
    wmctrl
    via
    ventoy-full

    kdePackages.qttools

    inputs.sddm-stray.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.kwin-effects-forceblur.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.librepods.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.inputactions.packages.${pkgs.stdenv.hostPlatform.system}.inputactions-ctl
    inputs.inputactions.packages.${pkgs.stdenv.hostPlatform.system}.inputactions-kwin

    (sddm-astronaut.override {
      embeddedTheme = "black_hole";
    })
  ];
}
