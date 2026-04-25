/**
  Declarative pi.dev coding agent install shared across all Home Manager hosts.
*/
{ pkgs, ... }:
{
  home.packages = [ pkgs.pi-coding-agent ];
}
