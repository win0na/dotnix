/** Bare-metal Home Manager profile for anix. */
{ ... }: {
  home.file.".config/kwalletrc".text = ''
    [Wallet]
    Enabled=false
  '';

  dconf = {
    enable = true;

    settings = {
      "org/gnome/desktop/interface".color-scheme = "prefer-dark";
      "org/gnome/desktop/peripherals/touchpad".scroll-factor = 0.5;
    };
  };
}
