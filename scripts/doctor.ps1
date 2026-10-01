$ErrorActionPreference = 'Continue'
$fail = 0

function Check($name, $ok, $detail) {
    if ($ok) { Write-Host ("[ OK ] {0,-22} {1}" -f $name, $detail) -ForegroundColor Green }
    else { Write-Host ("[FAIL] {0,-22} {1}" -f $name, $detail) -ForegroundColor Red; $script:fail++ }
}
function Warn($name, $detail) {
    Write-Host ("[WARN] {0,-22} {1}" -f $name, $detail) -ForegroundColor Yellow
}

. "$PSScriptRoot\lib.ps1"

# tools
$uv = Get-Command uv -ErrorAction SilentlyContinue
Check 'uv' ($null -ne $uv) $(if ($uv) { (uv --version) } else { 'not found: winget install astral-sh.uv' })

# venv + package
$nitropy = Join-Path $PSScriptRoot '..\.venv\Scripts\nitropy.exe'
Check 'venv' (Test-Path $nitropy) $(if (Test-Path $nitropy) { $nitropy } else { 'missing: run `just sync`' })
if (Test-Path $nitropy) {
    $ver = (uv pip list 2>$null | Select-String '^pynitrokey\s+(\S+)').Matches.Groups[1].Value
    Check 'pynitrokey' ([bool]$ver) $(if ($ver) { $ver } else { 'not installed: run `just sync`' })
}

# privileges
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) { Check 'admin' $true 'elevated shell' }
else { Warn 'admin' 'not elevated; `just nitropy` will elevate on demand' }

# elevation method used when not admin
if (Test-SudoInline) { Check 'elevation' $true 'sudo, inline mode' }
elseif (Get-Command sudo -ErrorAction SilentlyContinue) {
    Warn 'elevation' 'sudo is not in Inline mode: using a UAC window instead (set Inline in Settings > System > For developers for in-terminal output)'
} else {
    Warn 'elevation' 'no sudo (Windows 10?): using a UAC window; output is relayed after the window closes'
}

# optional PATH shim
$shimDir = Join-Path $env:LOCALAPPDATA 'nitropy-quickstart\bin'
if (Test-Path (Join-Path $shimDir 'nitropy.cmd')) { Check 'PATH shim' $true "$shimDir\nitropy.cmd" }
else { Warn 'PATH shim' 'not installed (optional): just install-shim' }

# device
$devs = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match '^HID\\VID_20A0' }
Check 'Nitrokey (HID)' ($null -ne $devs -and @($devs).Count -gt 0) $(if ($devs) { (@($devs) | ForEach-Object { $_.InstanceId }) -join '; ' } else { 'no device seen: plug it in directly, no hub' })

if ($fail) { Write-Host "`n$fail check(s) failed" -ForegroundColor Red; exit 1 }
Write-Host "`nall good" -ForegroundColor Green
