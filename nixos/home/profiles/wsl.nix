/**
  WSL Home Manager profile for apc with Windows-hosted VS Code and a separate tunnel path.
*/
{ lib, ... }:
{
  imports = [ ../../../home/features/vscode-tunnel.nix ];

  programs.vscode.enable = lib.mkForce false;
}
