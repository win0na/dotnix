/**
  Declarative Python runtime shared across all Home Manager hosts via mise.
*/
{ ... }:
{
  programs.mise.globalConfig.tools.python = "3.13";
  programs.mise.globalConfig.settings.python.compile = false;
}
