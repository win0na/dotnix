# home

shared Home Manager defaults and feature composition live here.

- `common.nix` owns cross-host home defaults
- `features/` owns opt-in feature modules and their paired assets
- keep shell/tool configs in Home Manager unless the behavior must be system-level
- when a feature has both `.nix` and data/config files, update both together
