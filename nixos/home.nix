{ pkgs, lib, inputs, user, email, ... }: {
  imports = [ ../shared_home.nix ];

  dconf = {
    enable = true;

    settings = {
      "org/gnome/desktop/interface".color-scheme = "prefer-dark";
      "org/gnome/desktop/peripherals/touchpad".scroll-factor = 0.5;
    };
  };
}
