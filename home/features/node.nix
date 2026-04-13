/** Declarative Node.js runtime shared across all Home Manager hosts via mise. */
{ ... }: {
  programs.mise.globalConfig.tools.node = "lts";
}
