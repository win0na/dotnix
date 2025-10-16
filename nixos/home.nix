{ pkgs, lib, inputs, user, email, ... }: {
  imports = [ ../shared_home.nix ];

  dconf = {
    enable = true;
    settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };
  
  # zen-browser-flake does not support x86_64-darwin
  programs.zen-browser.enable = true;
}