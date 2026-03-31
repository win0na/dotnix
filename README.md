# dotnix

.nix, my custom nix-darwin & NixOS configuration.

## Hosts

| Host | Platform | Flake attr | Purpose |
|------|----------|------------|---------|
| **wnix** | NixOS (`x86_64-linux`) | `.#wnix` | Linux host with flake-selected `bare` or `wsl` profile |
| **wmac** | nix-darwin (`x86_64-darwin`) | `.#wmac` | macOS build server (Xcode, Homebrew) |

Both hosts use [Lix](https://lix.systems) as their Nix implementation.

`wnix` has two profiles behind a single NixOS configuration entry:

- `bare` for the desktop/gaming machine
- `wsl` for WSL2/WSLg

The active `wnix` profile is selected in `flake.nix` via `wnixMode`.

## Prerequisites

- [Nix](https://nixos.org/download/) or [Lix](https://lix.systems/install/) with flakes enabled
- For **wmac**: macOS with [Homebrew](https://brew.sh) and [nix-darwin](https://github.com/nix-darwin/nix-darwin), signed into the Mac App Store
- For **wnix bare**: a target machine reachable via SSH for remote deploys
- For **wnix wsl**: Windows with WSL2/WSLg enabled

### WSL networking

`wnix` in WSL mode assumes mirrored networking is enabled on Windows:

```ini
[wsl2]
networkingMode=mirrored
```

This lives in `%UserProfile%\.wslconfig` on Windows, not in the NixOS guest.

## Rebuild

### NixOS (`wnix`)

From the repository root on the target machine:

```sh
sudo nixos-rebuild switch --flake .#wnix
```

For WSL mode, set `wnixMode = "wsl";` in `flake.nix` first.

### nix-darwin (`wmac`)

From the repository root on the target Mac:

```sh
sudo darwin-rebuild switch --flake .#wmac
```

## Automatic deployment

### NixOS bare (`nixos-anywhere`)

The bare `wnix` profile can be deployed to a fresh machine remotely using [nixos-anywhere](https://github.com/nix-community/nixos-anywhere).

1. Boot the target machine into a NixOS installer image.
2. Set a root password:

```sh
sudo passwd root
```

3. Deploy from the source machine:

```sh
SSHPASS="<TARGET_PASSWORD>" nix run github:nix-community/nixos-anywhere -- \
  --env-password \
  --generate-hardware-config nixos-facter ./facter.json \
  --flake .#wnix \
  --target-host root@<IP_ADDRESS_OF_TARGET>
```

This uses `nixos/disk.nix`, which is only imported when `wnixMode = "bare"`.

### nix-darwin bootstrap

On a fresh Mac with the prerequisites installed:

```sh
git clone https://github.com/win0na/dotnix.git ~/wmac && \
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/wmac#wmac
```

## Day-to-day commands

| Task | Command |
|------|---------|
| Rebuild NixOS | `sudo nixos-rebuild switch --flake .#wnix` |
| Rebuild NixOS (WSL mode) | Set `wnixMode = "wsl"` in `flake.nix`, then run `sudo nixos-rebuild switch --flake .#wnix` |
| Enable WSL mirrored networking | Add `[wsl2] networkingMode=mirrored` to `%UserProfile%\.wslconfig`, then restart WSL |
| Rebuild macOS | `sudo darwin-rebuild switch --flake .#wmac` |
| Format all Nix files | `nix fmt` |
| Update flake inputs | `nix flake update` |
| Upgrade Mac App Store apps | `mas upgrade` |

The `sw` alias is defined on both hosts and runs the appropriate rebuild command with `--show-trace`.

## Repository structure

```text
flake.nix              # Flake entry point, defines both host configs and selects wnix profile mode
common/
  system.nix           # System config shared by both hosts (Lix, overlays, base packages)
home/
  common.nix           # Home Manager config shared by both users (git, ssh, vscode, zsh, mise)
  features/
    opencode.nix              # Declarative OpenCode install and config for NixOS home profiles
    1password-darwin.nix     # 1Password signing/agent wiring for macOS
    1password-linux-gui.nix  # 1Password signing/agent wiring for bare Linux
    1password-wsl.nix        # WSL 1Password behavior via Windows-hosted helpers
    opencode/
      opencode.json            # Global OpenCode config
      oh-my-opencode-slim.json # oh-my-opencode-slim preset config
darwin/
  config.nix           # wmac system config
  home.nix             # wmac Home Manager entrypoint
nixos/
  default.nix          # wnix system selector
  common.nix           # wnix system settings shared by bare and wsl
  networking/
    default.nix        # wnix networking selector
    common.nix         # wnix networking settings shared by bare and wsl
    bare.nix           # bare networking via NetworkManager
    wsl.nix            # wsl networking via NixOS-WSL guest config
  users.nix            # wnix user and group definitions
  docker.nix           # wnix Docker config shared by bare and wsl
  disk.nix             # Disko partition layout for nixos-anywhere bare deployments
  home/
    default.nix        # wnix Home Manager selector
    profiles/
      bare.nix         # bare Home Manager profile
      wsl.nix          # wsl Home Manager profile
  profiles/
    bare/
      default.nix      # bare profile selector
      boot.nix         # bootloader, kernel, initrd, plymouth
      hardware.nix     # hardware, bluetooth, graphics
      audio.nix        # pipewire and realtime audio services
      desktop.nix      # Plasma, SDDM, appimage, GUI session services
      gaming.nix       # Jovian, Steam, Proton, Sunshine, gaming env vars
      peripherals.nix  # Solaar, udev rules, thermald, bluetooth systemd drop-ins
      1password.nix    # bare Linux 1Password GUI integration
      virtualization.nix # bare-only virtualization beyond Docker
      packages.nix     # bare desktop/gaming package set
    wsl/
      default.nix      # WSL2 profile (NixOS-WSL, Docker, WSLg-oriented settings)
facter.json            # Hardware detection output for bare deployments
```

## Notable configuration patterns

- Shared cross-host system config lives in `common/system.nix`.
- Shared Home Manager config lives in `home/common.nix`.
- `mise` plus the pinned `jbadeau/mise-nix` plugin are configured declaratively from `home/common.nix`.
- OpenCode is managed declaratively from `home/features/opencode.nix` and `home/features/opencode/`.
- 1Password integration is split by platform rather than living in the shared home module.
- WSL commit signing uses the Windows-hosted 1Password helper exposed into WSL.
- Mutable OpenCode auth and cache files are intentionally left unmanaged.
