$ErrorActionPreference = 'Stop'

$bootstrapUrl = 'https://raw.githubusercontent.com/win0na/a.nix/main/scripts/install-anix'
$wslUrl = 'https://github.com/nix-community/NixOS-WSL/releases/latest/download/nixos.wsl'
$tmp = Join-Path $env:TEMP 'nixos.wsl'

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Start-Process -FilePath powershell.exe -Verb RunAs -Wait -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File', $PSCommandPath)
  exit $LASTEXITCODE
}

& wsl.exe --install --no-distribution
Invoke-WebRequest -Uri $wslUrl -OutFile $tmp
& wsl.exe --install --from-file $tmp

try {
  & wsl.exe -d NixOS --exec /bin/sh -lc 'printf ready' | Out-Null
} catch {
  Write-Host 'NixOS-WSL is not ready yet. Re-run this command after reboot/sign-in if needed.'
  exit 1
}

& wsl.exe -d NixOS --exec bash -lc "curl -fsSL '$bootstrapUrl' -o /tmp/install-anix && bash /tmp/install-anix a.pc"
