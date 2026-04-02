# darwin

darwin-specific policy and entrypoints live here.

- keep darwin behavior separate from linux shared modules
- prefer matching existing nix-darwin + Home Manager boundaries
- if a change also affects shared home behavior, update `home/common.nix` or the relevant feature instead of duplicating logic here
- verify with the darwin output only when possible
