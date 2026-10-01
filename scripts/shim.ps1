param([Parameter(Mandatory)][ValidateSet('install', 'uninstall')][string]$Action)

# Optional: put a `nitropy` command on the user PATH. It is a tiny nitropy.cmd in its
# own directory (so no Python/pip from the venv shadows anything) that calls
# scripts\nitropy.ps1, which handles elevation. The venv is never put on PATH.

$shimDir = Join-Path $env:LOCALAPPDATA 'nitropy-quickstart\bin'
$shim = Join-Path $shimDir 'nitropy.cmd'
$script = (Resolve-Path (Join-Path $PSScriptRoot 'nitropy.ps1')).Path

# Edit the raw user PATH (keeps %VAR% entries unexpanded, unlike [Environment]::SetEnvironmentVariable)
function Set-UserPath([scriptblock]$Edit) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
    try {
        $raw = $key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $parts = @($raw -split ';' | Where-Object { $_ })
        $new = @(& $Edit $parts)
        $key.SetValue('Path', ($new -join ';'), [Microsoft.Win32.RegistryValueKind]::ExpandString)
    } finally { $key.Close() }
    # tell running programs (new terminals) that the environment changed
    Add-Type -Namespace Win32 -Name Native -MemberDefinition @'
[DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, UIntPtr w, string l, uint f, uint t, out UIntPtr r);
'@
    $r = [UIntPtr]::Zero
    [void][Win32.Native]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$r)
}

if ($Action -eq 'install') {
    New-Item -ItemType Directory -Force $shimDir | Out-Null
    $cmd = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"$script`" %*`r`nexit /b %ERRORLEVEL%`r`n"
    [IO.File]::WriteAllText($shim, $cmd, [Text.Encoding]::ASCII)
    Set-UserPath { param($p) if ($p -notcontains $shimDir) { $p + $shimDir } else { $p } }
    Write-Host "installed: $shim" -ForegroundColor Green
    Write-Host "added to user PATH: $shimDir"
    Write-Host 'Open a NEW terminal, then run: nitropy version'
} else {
    Set-UserPath { param($p) $p | Where-Object { $_ -ne $shimDir } }
    if (Test-Path $shimDir) { Remove-Item $shimDir -Recurse -Force }
    $parent = Split-Path $shimDir
    if ((Test-Path $parent) -and -not (Get-ChildItem $parent)) { Remove-Item $parent -Force }
    Write-Host 'shim removed, PATH entry removed' -ForegroundColor Green
}
