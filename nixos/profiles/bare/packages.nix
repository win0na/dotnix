/**
  Bare-metal desktop, gaming, and hardware-oriented packages.
*/
{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  librepods =
    let
      craneLib = inputs.librepods.inputs.crane.mkLib pkgs;
      root = builtins.path {
        path = inputs.librepods + /linux-rust;
        name = "librepods-linux-rust";
      };
      src = root;
      buildInputs = with pkgs; [
        dbus
        libpulseaudio
        alsa-lib
        bluez
        expat
        fontconfig
        freetype
        freetype.dev
        libGL
        pkg-config
        libx11
        libxcursor
        libxi
        libxrandr
        wayland
        libxkbcommon
        vulkan-loader
      ];
      nativeBuildInputs = with pkgs; [
        pkg-config
        makeWrapper
      ];
      commonArgs = {
        inherit buildInputs nativeBuildInputs src;
        strictDeps = true;
      };
    in
    craneLib.buildPackage (
      commonArgs
      // {
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        doCheck = false;
        postInstall = ''
          wrapProgram $out/bin/librepods \
            --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath buildInputs}
        '';
        meta = {
          description = "AirPods liberated from Apple's ecosystem";
          homepage = "https://github.com/kavishdevar/librepods";
          license = lib.licenses.gpl3Only;
        };
      }
    );
in
{
  nixpkgs.config.permittedInsecurePackages = [
    "ventoy-1.1.10"
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
    wineWow64Packages.stable
    wlr-randr
    wmctrl
    via
    ventoy-full

    kdePackages.qttools

    inputs.sddm-stray.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.kwin-effects-forceblur.packages.${pkgs.stdenv.hostPlatform.system}.default
    librepods
    inputs.inputactions.packages.${pkgs.stdenv.hostPlatform.system}.inputactions-ctl
    inputs.inputactions.packages.${pkgs.stdenv.hostPlatform.system}.inputactions-kwin

    (sddm-astronaut.override {
      embeddedTheme = "black_hole";
    })
  ];
}
