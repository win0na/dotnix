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

all hosts use [lix](https://lix.systems).

## quickstart

### a.nix

```sh
# in nixos:

nix run github:numtide/nixos-facter -- ./facter.json
git clone https://github.com/win0na/a.nix.git ~/a.nix && cd ~/a.nix
sudo nixos-rebuild switch --flake .#anix
```

### a.pc (wsl)

```powershell
# in powershell:

# add this to %UserProfile%\.wslconfig first:
# [wsl2]
# networkingMode=mirrored

$wslUrl = "https://github.com/nix-community/NixOS-WSL/releases/latest/download/nixos.wsl"
$wslFile = "$env:TEMP\nixos.wsl"
wsl --install --no-distribution
Invoke-WebRequest -Uri $wslUrl -OutFile $wslFile
wsl --install --from-file $wslFile
wsl -d NixOS
```

```sh
# in wsl:

git clone https://github.com/win0na/a.nix.git ~/a.nix && cd ~/a.nix
sudo nixos-rebuild switch --flake .#apc
```

### a.mac

```sh
# in macos:

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"

# sign into the mac app store before running this.
git clone https://github.com/win0na/a.nix.git ~/a.nix && cd ~/a.nix
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#amac
```

## rebuild

```sh
# a.nix
sudo nixos-rebuild switch --flake .#anix

# a.pc (wsl)
sudo nixos-rebuild switch --flake .#apc

# a.mac
sudo darwin-rebuild switch --flake .#amac
```

the `sw` alias is available on all hosts. it rebuilds the repo clone at `~/a.nix` with `--show-trace`.

## deploy

### a.nix (via nixos-anywhere)

```sh
# in nixos:

# boot the target into a nixos installer and note the ipv4 address.
# then set a root password.
sudo passwd root
```

```sh
# on the source machine:

# set the following variables.
targetHost="root@<IP_ADDRESS_OF_TARGET>"
targetPassword="<TARGET_PASSWORD>"

# then run:
tmpDir="$(mktemp -d)/a.nix"
git clone https://github.com/win0na/a.nix.git "$tmpDir" && cd $tmpDir
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

- `a.pc` uses mirrored networking from windows via `%UserProfile%\.wslconfig`
- `a.pc` signs git commits through the windows-hosted 1password helper
- `anix` and `apc` use `ollama-rocm`
- `amac` runs `ollama serve` via launchd
- opencode config is declarative; auth and runtime caches are intentionally unmanaged
- zsh is managed through home manager with oh-my-zsh + the headline theme
