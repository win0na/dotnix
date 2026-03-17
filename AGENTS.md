# AGENTS.md

## Overview

Dual NixOS + nix-darwin configuration flake. Two hosts, one user (`winona`), shared modules. Uses Lix (not CppNix) as the Nix implementation, managed via `pkgs.lixPackageSets.stable` from nixpkgs.

## Hosts

| Name | Platform | Flake attr | Purpose |
|------|----------|------------|---------|
| `wnix` | `x86_64-linux` | `nixosConfigurations.wnix` | Desktop + gaming (KDE Plasma, Steam/Gamescope, Jovian) |
| `wmac` | `x86_64-darwin` | `darwinConfigurations.wmac` | macOS build server (Xcode, Homebrew, headless-capable) |

Hostnames are passed declaratively via `specialArgs.hostname` from `flake.nix` into each config, then used as `networking.hostName` (and `networking.computerName` on darwin).

## File Layout

```
flake.nix              # Flake entry point, defines both host configs
shared_config.nix      # System config shared by both hosts (Lix, overlays, base packages)
shared_home.nix        # Home Manager config shared by both users (git, ssh, vscode, zsh)
darwin/
  config.nix           # wmac system config (homebrew, dock, launchd, Xcode tooling)
  home.nix             # wmac home-manager (imports shared_home.nix only)
nixos/
  config.nix           # wnix system config (boot, hardware, services, gaming)
  home.nix             # wnix home-manager (zen-browser, KDE dconf, mime associations)
  disk.nix             # Disko partition layout for nixos-anywhere deployments
  firmware/brcm/       # Broadcom firmware blobs for Apple hardware
facter.json            # Hardware detection output (generated, not committed on fresh installs)
```

## Key Patterns

- **Shared modules** are imported via `imports = [ ../shared_config.nix ]` and `imports = [ ../shared_home.nix ]`.
- **`specialArgs`** passes `self`, `inputs`, `user`, and `hostname` into system modules. Home Manager receives `inputs`, `user`, and `email` via `extraSpecialArgs`.
- **Platform branching** in shared modules uses `pkgs.stdenv.isDarwin` / `pkgs.stdenv.isLinux` (see `shared_home.nix` for examples in git signing and ssh agent paths).
- **Lix** is set in `shared_config.nix` via `nix.package` and an overlay that rewires `nixpkgs-review`, `nix-eval-jobs`, and `nix-fast-build`.
- **Doc comments** follow RFC 145 (`/** ... */` before each module function).

## Conventions

- All `.nix` files use `nixfmt-rfc-style` (formatter defined in flake outputs).
- Homebrew is only used on darwin; the `masApps` entries require being signed into the Mac App Store.
- The darwin `postActivation` script handles imperative installs (Xcode via `xcodes`, `supergateway` via npm) that can't be managed declaratively.
- A `launchd.daemons.caffeinate` service keeps the mac display awake at all times.

## Common Tasks

| Task | Command |
|------|---------|
| Rebuild NixOS | `sudo nixos-rebuild switch --flake .#wnix` |
| Rebuild macOS | `sudo darwin-rebuild switch --flake .#wmac` |
| Format files | `nix fmt` |
| Deploy NixOS remotely | See `nixos/disk.nix` doc comment for nixos-anywhere command |
