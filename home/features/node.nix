/**
  Declarative Node.js runtime shared across all Home Manager hosts via mise.
*/
{ ... }:
{
  programs.mise.globalConfig.tools.node = "lts";
  programs.mise.globalConfig.settings.node.compile = false;
}
