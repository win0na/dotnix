# AGENTS.md

## Overview

Dual NixOS + nix-darwin configuration flake. Two hosts, one user (`winona`), shared modules. Uses Lix (not CppNix) as the Nix implementation, managed via `pkgs.lixPackageSets.stable` from nixpkgs.

`wnix` now has two flake-selected Linux profiles behind a single `nixosConfigurations.wnix` entry:
- `bare` for the desktop/gaming machine
- `wsl` for WSL2/WSLg

## Hosts

| Name | Platform | Flake attr | Purpose |
|------|----------|------------|---------|
| `wnix` | `x86_64-linux` | `nixosConfigurations.wnix` | Linux host with flake-selected `bare` or `wsl` profile |
| `wmac` | `x86_64-darwin` | `darwinConfigurations.wmac` | macOS build server (Xcode, Homebrew, headless-capable) |

Hostnames are passed declaratively via `specialArgs.hostname` from `flake.nix` into each config, then used as `networking.hostName` (and `networking.computerName` on darwin). The `wnix` profile is selected in `flake.nix` via `specialArgs.wnixMode`.

## File Layout

```
flake.nix              # Flake entry point, defines both host configs and selects wnix profile mode
common/
  system.nix           # System config shared by both hosts (Lix, overlays, base packages)
home/
  common.nix           # Home Manager config shared by both users (git, ssh, vscode, zsh)
  features/
    opencode.nix              # Declarative OpenCode install and config for NixOS home profiles
    1password-darwin.nix     # 1Password signing/agent wiring for macOS
    1password-linux-gui.nix  # 1Password signing/agent wiring for bare Linux
    1password-wsl.nix        # WSL 1Password behavior without Linux GUI integration
    opencode/
      opencode.json            # Global OpenCode config (plugins, MCPs, providers, agent disables)
      oh-my-opencode-slim.json # oh-my-opencode-slim preset and agent configuration
darwin/
  config.nix           # wmac system config (homebrew, dock, launchd, Xcode tooling)
  home.nix             # wmac home-manager imports home/common + darwin 1Password feature
nixos/
  default.nix          # wnix system selector importing common + profile modules
  common.nix           # wnix system settings shared by bare and wsl
  networking/
    default.nix        # wnix networking selector importing common + profile networking
    common.nix         # wnix networking settings shared by bare and wsl
    bare.nix           # bare networking via NetworkManager and firewall rules
    wsl.nix            # wsl networking via NixOS-WSL-managed hosts/resolver config
  users.nix            # wnix user and group definitions selected by profile mode
  docker.nix           # wnix Docker config shared by bare and wsl
  disk.nix             # Disko partition layout for nixos-anywhere deployments
  home/
    default.nix        # wnix home-manager selector importing home/common + profile modules
    profiles/
      bare.nix         # bare home-manager profile (dconf and desktop user settings)
      wsl.nix          # wsl home-manager profile
  profiles/
    bare/
      default.nix      # bare profile selector
      boot.nix         # bootloader, kernel, initrd, plymouth
      hardware.nix     # firmware, bluetooth, and graphics settings
      audio.nix        # pipewire and realtime audio services
      desktop.nix      # Plasma, SDDM, appimage, GUI session services
      gaming.nix       # Jovian, Steam, Proton, Sunshine, gaming env vars
      peripherals.nix  # Solaar, udev rules, thermald, bluetooth systemd drop-ins
      1password.nix    # bare Linux 1Password GUI integration
      virtualization.nix # bare-only virtualization beyond Docker
      packages.nix     # bare desktop/gaming package set
    wsl/
      default.nix      # WSL2 profile (NixOS-WSL, Docker, WSLg-oriented settings)
facter.json            # Hardware detection output (generated, not committed on fresh installs)
```

## Key Patterns

- **Cross-host common modules** now live in `common/system.nix` and `home/common.nix`, imported from thin host selectors.
- **`mise` + `mise-nix`** are configured from `home/common.nix`; Home Manager installs the `mise` CLI, symlinks the pinned `jbadeau/mise-nix` plugin into `~/.local/share/mise/plugins/nix`, and bootstraps `node@latest` on first activation.
- **`specialArgs`** passes `self`, `inputs`, `user`, `hostname`, and `wnixMode` into the NixOS wnix module graph. Home Manager receives `inputs`, `user`, `email`, and `wnixMode` via `extraSpecialArgs`.
- **Profile selection** for `wnix` happens in `flake.nix`, which loads either the `bare` or `wsl` module tree under the single `nixosConfigurations.wnix` entry.
- **Networking** is selected separately via `nixos/networking/default.nix`, which loads the `bare` NetworkManager stack or the `wsl` NixOS-WSL networking stack.
- **WSL mirrored networking** is configured from Windows via `%UserProfile%\.wslconfig`, not from the NixOS guest; the WSL networking module only manages guest-side `wsl.conf` network behavior.
- **1Password integration** is no longer configured in the shared home module; it lives in dedicated feature modules for darwin, bare Linux, and WSL.
- **OpenCode** is managed declaratively from `home/features/opencode.nix` and `home/features/opencode/`; auth state and runtime plugin caches are not managed in-repo.
- **Lix** is set in `common/system.nix` via `nix.package` and an overlay that rewires `nixpkgs-review`, `nix-eval-jobs`, and `nix-fast-build`.
- **Doc comments** follow RFC 145 (`/** ... */` before each module function).

## Maintenance

- Update this file when making major structural changes to the repo.
- Update this file when creating, deleting, renaming, or substantially repurposing `.nix` modules or directories.
- If a change affects profile selection, shared-vs-profile boundaries, or host behavior, reflect that here in `Overview`, `File Layout`, and `Key Patterns`.

## Source Conventions

- All `.nix` files use `nixfmt-rfc-style` (formatter defined in flake outputs).
- Homebrew is only used on darwin; the `masApps` entries require being signed into the Mac App Store.
- The darwin `postActivation` script handles imperative installs like Xcode via `xcodes` and `supergateway` via npm that can't be managed declaratively.
- A `launchd.daemons.caffeinate` service keeps the mac display awake at all times.
- WSL commit signing should not assume the Linux 1Password GUI app is available; WSL-specific 1Password behavior belongs in `home/features/1password-wsl.nix` and should use the Windows-hosted 1Password SSH/signing helpers exposed into WSL. Resolve the signer path dynamically instead of hardcoding a Windows username.
- OpenCode supports declarative config files in `~/.config/opencode`, but mutable auth/state files like `~/.local/share/opencode/auth.json`, `~/.cache/opencode/node_modules/`, and provider-specific account caches should remain unmanaged runtime state.
- WSL mirrored networking should be enabled on Windows with:
  ```ini
  [wsl2]
  networkingMode=mirrored
  ```
  The NixOS config does not manage `.wslconfig`.

## Git conventions
All commits in this repository must be **signed and verified**.

- Always create commits with `git commit -S`.
- If Git signing is not configured or signing fails, **do not commit**.
- Fail with the real reason from Git or GPG/SSH signing output instead of bypassing signing.
- Do not use unsigned commits as a fallback.
- Never add co-author trailers, attribution footers, AI credit lines, or similar metadata to commits unless the user explicitly requests them.
- Do not include lines such as:
  - `Co-authored-by: ...`
  - `Generated-by: ...`
  - `Created-with: ...`
  - `AI-assisted-by: ...`
- Keep commit messages clean and project-focused.

### Commit message format
Use this format for short commits:

`topic(short scope): description`

Examples:
- `ios(app): add nearby stops screen`
- `docs(arch): clarify transit data flow`
- `backend(api): normalize route status payload`

For larger commits, use the same first line, followed by short bullets and a final reasoning paragraph:

```text
topic(short scope): description

* change with short reasoning
* change with short reasoning
* change with short reasoning

Detailed change description & reasoning.
```

Guidance:
- `topic` should describe the area of work clearly and briefly.
- `scope` should name the primary file, directory, or subsystem.
- Keep the header concise and specific.
- The body should explain why the change exists, not just restate the diff.

## Common Tasks

| Task | Command |
|------|---------|
| Rebuild NixOS | `sudo nixos-rebuild switch --flake .#wnix` |
| Rebuild NixOS (WSL mode) | Set `wnixMode = "wsl"` in `flake.nix`, then run `sudo nixos-rebuild switch --flake .#wnix` |
| Enable WSL mirrored networking | Add `[wsl2] networkingMode=mirrored` to `%UserProfile%\.wslconfig` on Windows, then restart WSL |
| Rebuild macOS | `sudo darwin-rebuild switch --flake .#wmac` |
| Format files | `nix fmt` |
| Deploy NixOS remotely | See `nixos/disk.nix` doc comment for nixos-anywhere command |
