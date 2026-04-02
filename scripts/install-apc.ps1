$ErrorActionPreference = 'Stop'

$bootstrapUrl = 'https://raw.githubusercontent.com/win0na/anix/main/scripts/install-anix'
$wslUrl = 'https://github.com/nix-community/NixOS-WSL/releases/latest/download/nixos.wsl'
$tmp = Join-Path $env:TEMP 'nixos.wsl'

function Confirm-AnixConsent {
  param([string]$Prompt)
  $reply = Read-Host "$Prompt [y/N]"
  return $reply -match '^(?i:y|yes)$'
}

function Set-AnixMirroredNetworking {
  $wslConfig = Join-Path $env:USERPROFILE '.wslconfig'
  $lines = if (Test-Path $wslConfig) { [System.Collections.Generic.List[string]](Get-Content -Path $wslConfig) } else { [System.Collections.Generic.List[string]]::new() }

  if (-not (Confirm-AnixConsent 'configure mirrored networking in %USERPROFILE%\.wslconfig now?')) {
    Write-Host 'note: skipping mirrored networking setup.'
    return
  }

  $sectionIndex = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*\[wsl2\]\s*$') {
      $sectionIndex = $i
      break
    }
  }

  if ($sectionIndex -lt 0) {
    if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -ne '') {
      $lines.Add('') | Out-Null
    }
    $lines.Add('[wsl2]') | Out-Null
    $sectionIndex = $lines.Count - 1
  }

  $sectionEnd = $lines.Count
  for ($i = $sectionIndex + 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*\[.*\]\s*$') {
      $sectionEnd = $i
      break
    }
  }

  function Set-AnixWslKey([string]$key, [string]$value) {
    $foundIndex = -1
    for ($j = $sectionIndex + 1; $j -lt $sectionEnd; $j++) {
      if ($lines[$j] -match "^\s*$([regex]::Escape($key))\s*=") {
        if ($foundIndex -lt 0) {
          $lines[$j] = "$key=$value"
          $foundIndex = $j
        } else {
          $lines.RemoveAt($j)
          $j--
          $sectionEnd--
        }
      }
    }
    if ($foundIndex -lt 0) {
      $lines.Insert($sectionEnd, "$key=$value")
      $sectionEnd++
    }
  }

  Set-AnixWslKey 'networkingMode' 'Mirrored'
  Set-AnixWslKey 'dnsTunneling' 'true'

  try {
    Set-Content -Path $wslConfig -Value $lines
    & wsl.exe --shutdown | Out-Null
    Write-Host 'note: mirrored networking has been configured in %USERPROFILE%\.wslconfig.'
  } catch {
    Write-Warning 'failed to configure mirrored networking in %USERPROFILE%\.wslconfig; continuing without it'
  }
}

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  $scriptPath = $PSCommandPath
  if (-not $scriptPath) {
    $scriptPath = Join-Path $env:TEMP 'install-apc.ps1'
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/win0na/anix/main/scripts/install-apc.ps1' -OutFile $scriptPath
  }
  $proc = Start-Process -FilePath powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File', $scriptPath)
  exit $proc.ExitCode
}

Set-AnixMirroredNetworking

& wsl.exe --install --no-distribution
Invoke-WebRequest -Uri $wslUrl -OutFile $tmp
& wsl.exe --install --from-file $tmp

try {
  & wsl.exe -d NixOS --exec /bin/sh -lc 'printf ready' | Out-Null
} catch {
  Write-Host 'NixOS-WSL is not ready yet. Re-run this command after reboot/sign-in if needed.'
  exit 1
}

& wsl.exe -d NixOS --exec bash -lc "curl -fsSL '$bootstrapUrl' -o /tmp/install-anix && bash /tmp/install-anix apc"
