# the project that owns the venv; lets nitropy run from any directory (e.g. via the PATH shim)
$script:ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

# .python-version is the single source of truth for the Python version. Set UV_PYTHON from it
# so a global UV_PYTHON on the user's machine cannot override the project's pin.
$script:PyVer = (Get-Content (Join-Path $script:ProjectRoot '.python-version') -TotalCount 1).Trim()
$env:UV_PYTHON = $script:PyVer

function Test-Admin {
    $p = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Windows 11 sudo in Inline mode keeps output in the current terminal
function Test-SudoInline {
    if (-not (Get-Command sudo -ErrorAction SilentlyContinue)) { return $false }
    ((sudo config 2>&1 | Out-String) -match 'Inline')
}

# Build the script an elevated PowerShell runs: cd to the project, run nitropy
# with every argument single-quoted, tee all output to $OutFile, keep the exit code.
function New-ElevatedScript([string[]]$NitropyArgs, [string]$OutFile) {
    $quoted = ($NitropyArgs | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ' '
    $cwd = (Get-Location).Path -replace "'", "''"
    $proj = $script:ProjectRoot -replace "'", "''"
    $out = $OutFile -replace "'", "''"
    $py = $script:PyVer -replace "'", "''"
    @"
`$ProgressPreference = 'SilentlyContinue'
`$env:UV_PYTHON = '$py'
Set-Location '$cwd'
uv run --project '$proj' nitropy $quoted 2>&1 | ForEach-Object { "`$_" } | Tee-Object -FilePath '$out'
exit `$LASTEXITCODE
"@
}

# Fallback for Windows 10 / sudo not inline: elevate via a UAC prompt, run in a
# separate window (prompts like [y/N] are answered there), then relay the output.
function Invoke-ElevatedWindow([string[]]$NitropyArgs) {
    $tmp = Join-Path $env:TEMP ("nitropy-elevated-{0}.txt" -f [guid]::NewGuid())
    $script = New-ElevatedScript $NitropyArgs $tmp
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
    try {
        $proc = Start-Process powershell -Verb RunAs -Wait -PassThru `
            -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $enc
    } catch {
        Write-Host 'Elevation cancelled or failed.' -ForegroundColor Red
        $global:LASTEXITCODE = 1
        return
    }
    if (Test-Path $tmp) { Get-Content $tmp; Remove-Item $tmp -Force }
    $global:LASTEXITCODE = $proc.ExitCode
}

# Run nitropy with admin rights: directly, via inline sudo, or via a UAC window.
function Invoke-Nitropy {
    $root = $script:ProjectRoot
    $py = $script:PyVer
    if (Test-Admin) { & uv run --python $py --project $root nitropy @args }
    elseif (Test-SudoInline) { & sudo --inline uv run --python $py --project $root nitropy @args }
    else { Invoke-ElevatedWindow $args }
}
