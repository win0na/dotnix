{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    curl brave fastfetch git neovim python3Minimal qbittorrent wget vuetorrent
  ];
}