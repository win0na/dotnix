# home/features

feature modules should stay small and declarative.

- prefer one feature per file or subdirectory
- keep generated or vendor-like config assets beside the feature that owns them
- for opencode, keep `opencode.nix` aligned with files in `home/features/opencode/`
- avoid cross-feature coupling unless the dependency is explicit in nix
