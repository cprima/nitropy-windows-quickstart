. "$PSScriptRoot\lib.ps1"

$out = Invoke-Nitropy nk3 version 2>&1 | Out-String
$m = [regex]::Matches($out, 'v\d+\.\d+\.\d+')
if ($m.Count -eq 0) { Write-Host "Could not read device firmware version:`n$out" -ForegroundColor Red; exit 1 }
$installed = $m[$m.Count - 1].Value

try {
    $latest = (Invoke-RestMethod 'https://api.github.com/repos/Nitrokey/nitrokey-3-firmware/releases/latest').tag_name
} catch {
    Write-Host "Could not query latest release: $_" -ForegroundColor Red; exit 1
}

Write-Host "device : $installed"
Write-Host "latest : $latest"
if ([version]$installed.TrimStart('v') -ge [version]$latest.TrimStart('v')) {
    Write-Host 'up to date' -ForegroundColor Green
} else {
    Write-Host 'update available: just fw-update' -ForegroundColor Yellow
}
