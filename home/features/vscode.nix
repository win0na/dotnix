/**
  Local VS Code desktop configuration for non-WSL hosts.
*/
{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;

    profiles.default.extensions = with pkgs.vscode-marketplace; [
      bbenoist.nix
      nowsci.glassit-linux
    ];
  };
}
