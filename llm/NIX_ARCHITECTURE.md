# NIX_ARCHITECTURE.md

- `flake.nix`: top-level wiring, outputs, and shared module composition.
- `common/system.nix`: cross-host system defaults.
- `home/`: shared Home Manager modules plus feature modules.
- `nixos/common.nix`, `nixos/networking/`, `nixos/features/`, `nixos/home/`, `nixos/profiles/`: shared Linux layers split by concern, then host/profile-specific composition.
- `darwin/`: nix-darwin config plus the Home Manager entrypoint.
- root files that matter: `README.md` for usage, `AGENTS.md` for repo rules, `TEXT_STYLE.md` for writing style, `facter.json` for NixOS install/bootstrap hardware input.

## selection and boundaries

- Linux host/profile selection happens through separate flake outputs, not a local mode toggle.
- Shared modules own cross-host defaults; host/profile modules own machine-specific policy and overrides.
- Networking, home, and feature concerns stay split by directory so shared behavior is easy to reuse and host behavior stays isolated.

## notes

- keep this map high-level; read the referenced modules for exact host details.
