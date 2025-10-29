{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    curl brave fastfetch git neovim qbittorrent wget vuetorrent
  ];
}