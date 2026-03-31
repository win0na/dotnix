# a.nix

/æ nɪx/, my custom nix-darwin & NixOS configuration.

## Hosts

| Hostname | Platform | Flake attr | Purpose |
|----------|----------|------------|---------|
| **a.nix** | NixOS (`x86_64-linux`) | `.#anix` | Bare-metal desktop + gaming host |
| **a.pc** | NixOS (`x86_64-linux`) | `.#apc` | WSL2/WSLg profile with Docker |
| **a.mac** | nix-darwin (`x86_64-darwin`) | `.#amac` | macOS build server (Xcode, Homebrew) |

All hosts use [Lix](https://lix.systems) as their Nix implementation.

## Prerequisites

- [Nix](https://nixos.org/download/) or [Lix](https://lix.systems/install/) with flakes enabled
- For **a.mac**: macOS with [Homebrew](https://brew.sh) and [nix-darwin](https://github.com/nix-darwin/nix-darwin), signed into the Mac App Store
- For **a.nix**: a target machine reachable via SSH for remote deploys
- For **a.pc**: Windows with WSL2/WSLg enabled

### WSL networking

`a.pc` assumes mirrored networking is enabled on Windows:

```ini
[wsl2]
networkingMode=mirrored
```

This lives in `%UserProfile%\.wslconfig` on Windows, not in the NixOS guest.

## Rebuild

### NixOS bare (`a.nix`)

```sh
sudo nixos-rebuild switch --flake .#anix
```

### NixOS WSL (`a.pc`)

```sh
sudo nixos-rebuild switch --flake .#apc
```

### nix-darwin (`a.mac`)

```sh
sudo darwin-rebuild switch --flake .#amac
```

## Automatic deployment

### NixOS bare (`nixos-anywhere`)

The `a.nix` output can be deployed to a fresh machine remotely using [nixos-anywhere](https://github.com/nix-community/nixos-anywhere).

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
  --flake .#anix \
  --target-host root@<IP_ADDRESS_OF_TARGET>
```

### nix-darwin bootstrap

On a fresh Mac with the prerequisites installed:

```sh
git clone https://github.com/win0na/a.nix.git ~/a.nix && \
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/a.nix#amac
```

## Day-to-day commands

| Task | Command |
|------|---------|
| Rebuild bare NixOS | `sudo nixos-rebuild switch --flake .#anix` |
| Rebuild WSL NixOS | `sudo nixos-rebuild switch --flake .#apc` |
| Enable WSL mirrored networking | Add `[wsl2] networkingMode=mirrored` to `%UserProfile%\.wslconfig`, then restart WSL |
| Rebuild macOS | `sudo darwin-rebuild switch --flake .#amac` |
| Format all Nix files | `nix fmt` |
| Update flake inputs | `nix flake update` |
| Upgrade Mac App Store apps | `mas upgrade` |

The `sw` alias is defined on both platforms and runs the appropriate rebuild command with `--show-trace`.

## Repository structure

```text
flake.nix              # Flake entry point, defines a.nix, a.pc, and a.mac
common/
  system.nix           # System config shared by all hosts (Lix, overlays, base packages)
home/
  common.nix           # Home Manager config shared by all user profiles (git, ssh, vscode, zsh, mise)
  features/
    opencode.nix              # Declarative OpenCode install and config for NixOS home profiles
    1password-darwin.nix     # 1Password signing/agent wiring for macOS
    1password-linux-gui.nix  # 1Password signing/agent wiring for bare Linux
    1password-wsl.nix        # WSL 1Password behavior via Windows-hosted helpers
    opencode/
      opencode.json            # Global OpenCode config
      oh-my-opencode-slim.json # oh-my-opencode-slim preset config
darwin/
  config.nix           # a.mac system config
  home.nix             # a.mac Home Manager entrypoint
nixos/
  default.nix          # Root selector shared by a.nix and a.pc
  common.nix           # NixOS settings shared by bare and wsl profiles
  networking/
    default.nix        # networking selector shared by a.nix and a.pc
    common.nix         # networking settings shared by both Linux outputs
    bare.nix           # bare networking via NetworkManager
    wsl.nix            # wsl networking via NixOS-WSL guest config
  users.nix            # Linux user and group definitions
  docker.nix           # Docker config shared by a.nix and a.pc
  disk.nix             # Disko partition layout for a.nix nixos-anywhere deployments
  home/
    default.nix        # Home Manager selector shared by a.nix and a.pc
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
- `a.pc` commit signing uses the Windows-hosted 1Password helper exposed into WSL.
- Mutable OpenCode auth and cache files are intentionally left unmanaged.
