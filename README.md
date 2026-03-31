<div align="center">

# a.nix

`/æ nɪx/`

a nixos + nix-darwin flake for `a.nix`, `a.pc`, and `a.mac`.

linux. wsl2. macos. one repo.

<p>
  <a href="#quickstart">quickstart</a> •
  <a href="#rebuild">rebuild</a> •
  <a href="#deploy">deploy</a> •
  <a href="#common-commands">common commands</a>
</p>

</div>

## what it manages

| host | platform | flake attr | role |
|------|----------|------------|------|
| `a.nix` | nixos (`x86_64-linux`) | `.#anix` | bare-metal desktop + gaming host |
| `a.pc` | nixos (`x86_64-linux`) on wsl | `.#apc` | wsl2 / wslg build host |
| `a.mac` | nix-darwin (`x86_64-darwin`) | `.#amac` | macos build server |

all hosts use [lix](https://lix.systems), with [nix](https://github.com/NixOS/nix) as a fallback.

## quickstart

```sh
# linux & macos
curl -fsSL "https://raw.githubusercontent.com/win0na/a.nix/main/scripts/install-anix" | bash
```

```powershell
# windows 11
irm "https://raw.githubusercontent.com/win0na/a.nix/main/scripts/install-apc.ps1" | iex
```

### llm install (copy/paste)

```text
Fetch and run this bootstrap script:
https://raw.githubusercontent.com/win0na/a.nix/main/scripts/install-anix
```

## rebuild

use `sw` where the alias exists.

if all else fails:

```sh
# in a.nix's working directory (def: $HOME/a.nix)
sudo env ANIX_INSTALL_OPTIONS_FILE=/etc/a.nix/install-options.json nixos-rebuild switch --impure --flake .#anix
sudo env ANIX_INSTALL_OPTIONS_FILE=/etc/a.nix/install-options.json nixos-rebuild switch --impure --flake .#apc
sudo env ANIX_INSTALL_OPTIONS_FILE=/etc/a.nix/install-options.json darwin-rebuild switch --impure --flake .#amac
```

## deploy

### a.nix (via [nixos-anywhere](https://github.com/nix-community/nixos-anywhere))

```sh
# on the target machine:

# boot into a nixos installer and set a root password.
sudo passwd root

# note the ipv4/6 address before continuing
ip addr
```

```sh
# on the source machine:

# set the following variables.
targetHost="root@<IP_ADDRESS_OF_TARGET>"
targetPassword="<TARGET_PASSWORD>"

# this path assumes the target install disk matches nixos/default-disko.nix.
# verify the disk path yourself before installing.

# then run:
tmpDir="$(mktemp -d)/a.nix"
git clone https://github.com/win0na/a.nix.git "$tmpDir" && cd "$tmpDir"
SSHPASS="$targetPassword" nix run github:nix-community/nixos-anywhere -- \
  --env-password \
  --generate-hardware-config nixos-facter ./facter.json \
  --flake .#anix \
  --target-host "$targetHost"
```

## common commands

```sh
nix fmt                 # format nix files
nix flake update        # update flake inputs
mas upgrade             # upgrade app store apps on a.mac
```

## notable bits

- `a.nix` uses disko in the live-installer `a.nix` flow with an explicit destructive confirmation prompt
- `a.pc` requires mirrored networking from windows via `%UserProfile%\.wslconfig`:

  ```ini
  [wsl2]
  networkingMode=Mirrored
  dnsTunneling=true
  ```
- `a.pc` can bootstrap from Windows first, then continue inside the NixOS-WSL guest
- `a.mac` checks for brew, mas, and nix/lix before rebuilding
- `a.nix` and `a.pc` use `ollama-rocm`
- `a.mac` runs `ollama serve` via launchd
- opencode config is declarative; auth and runtime caches are intentionally unmanaged
- zsh is managed through home manager with oh-my-zsh + the headline theme
