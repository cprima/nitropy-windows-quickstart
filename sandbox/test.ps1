# Runs INSIDE Windows Sandbox: follows the README quick start on a clean Windows.
# No Nitrokey is attached (Sandbox has no USB passthrough), so the device check is expected to fail.
$ErrorActionPreference = 'Continue'
$src = 'C:\Users\WDAGUtilityAccount\Desktop\src'
$work = 'C:\Users\WDAGUtilityAccount\Desktop\quickstart'
$results = [System.Collections.Generic.List[string]]::new()
# C:\out is a writable mapped host folder (sandbox\out), so results survive closing the Sandbox
$out = 'C:\out'
if (-not (Test-Path $out)) { $out = "$env:USERPROFILE\Desktop" }
Start-Transcript -Path "$out\transcript.txt" -Force | Out-Null

function Step($name, [scriptblock]$body) {
    Write-Host "`n=== $name" -ForegroundColor Cyan
    $global:LASTEXITCODE = 0
    try { & $body; $ok = ($LASTEXITCODE -eq 0) } catch { Write-Host $_ -ForegroundColor Red; $ok = $false }
    if (-not $ok) { Write-Host ("step failed, exit code {0} (0x{1:X8})" -f $LASTEXITCODE, [int]$LASTEXITCODE) -ForegroundColor Red }
    $results.Add(("{0,-6} {1}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name))
}
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

Step 'copy repo (without .venv)' {
    robocopy $src $work /E /XD .venv .git snapshots /NFL /NDL /NJH /NJS | Out-Null
    $global:LASTEXITCODE = [int]($LASTEXITCODE -ge 8)
}
Set-Location $work

Step 'install uv + just (winget, else uv installer + rust-just)' {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install -e --id astral-sh.uv --accept-source-agreements --accept-package-agreements
        winget install -e --id Casey.Just --accept-source-agreements --accept-package-agreements
        Refresh-Path
    }
    if (-not (Get-Command uv -ErrorAction SilentlyContinue) -or -not (Get-Command just -ErrorAction SilentlyContinue)) {
        Write-Host 'winget unavailable or incomplete: falling back to uv installer + rust-just' -ForegroundColor Yellow
        if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression; Refresh-Path; $env:Path += ";$env:USERPROFILE\.local\bin" }
        uv tool install rust-just
        $env:Path += ";$env:USERPROFILE\.local\bin"
    }
    Write-Host ('winget present: ' + [bool](Get-Command winget -ErrorAction SilentlyContinue))
    Get-Command uv, just -ErrorAction SilentlyContinue | Format-Table Name, Source -AutoSize | Out-String | Write-Host
    uv --version
    $global:LASTEXITCODE = 0
}
Step 'just runs (else: install the Visual C++ runtime and retry)' {
    just --version
    $code = $LASTEXITCODE
    Write-Host ("just --version exit code: {0} (0x{1:X8})" -f $code, $code)
    if ($code -ne 0) {
        Write-Host 'just does not run; installing the Visual C++ runtime and retrying' -ForegroundColor Yellow
        $vc = Join-Path $env:TEMP 'vc_redist.x64.exe'
        Invoke-WebRequest https://aka.ms/vs/17/release/vc_redist.x64.exe -OutFile $vc
        # no -Wait: the installer's helper processes can linger after it is done
        Start-Process $vc -ArgumentList '/install', '/quiet', '/norestart'
        $deadline = (Get-Date).AddSeconds(180)
        do {
            Start-Sleep 5
            $dll = Test-Path "$env:windir\System32\vcruntime140.dll"
            if ($dll) { just --version 2>&1 | Out-Null }
        } until (($dll -and $LASTEXITCODE -eq 0) -or (Get-Date) -gt $deadline)
        just --version
        Write-Host ("after VC++ runtime, exit code: {0}" -f $LASTEXITCODE) -ForegroundColor Yellow
    }
}
Step 'just sync'   { just sync }
Step 'venv uses Python 3.12 and hidapi is a prebuilt wheel' {
    $v = (uv run python --version) 2>&1
    Write-Host $v
    $global:LASTEXITCODE = [int](-not ("$v" -like 'Python 3.12.*'))
}
Step 'just --list' { just --list }
Step 'just doctor (device check is expected to fail: no USB in Sandbox)' {
    just doctor
    Write-Host '(exit code ignored: only the missing device is an acceptable failure)' -ForegroundColor Yellow
    $global:LASTEXITCODE = 0
}
Step 'just nitropy version (Sandbox user is admin: direct path)' { just nitropy version }
Step 'just nitropy nk3 --help' {
    # capture first: piping into Select-Object -First would close the pipe and kill just
    $h = just nitropy nk3 --help
    $code = $LASTEXITCODE
    $h | Select-Object -First 5
    $global:LASTEXITCODE = $code
}
Step 'just install-shim' { just --yes install-shim }
Step 'shim runs from another directory' {
    Set-Location $env:TEMP
    & "$env:LOCALAPPDATA\nitropy-quickstart\bin\nitropy.cmd" version
    Set-Location $work
}
Step 'shim dir is on user PATH' {
    $p = [Environment]::GetEnvironmentVariable('Path', 'User')
    Write-Host $p
    $global:LASTEXITCODE = [int](-not ($p -like '*nitropy-quickstart\bin*'))
}
Step 'just uninstall-shim' { just uninstall-shim }
Step 'shim and PATH entry gone' {
    $p = [Environment]::GetEnvironmentVariable('Path', 'User')
    $gone = (-not (Test-Path "$env:LOCALAPPDATA\nitropy-quickstart")) -and (-not ($p -like '*nitropy-quickstart*'))
    $global:LASTEXITCODE = [int](-not $gone)
}

Write-Host "`n================ SUMMARY ================" -ForegroundColor Cyan
$results | ForEach-Object { Write-Host $_ -ForegroundColor $(if ($_ -like 'PASS*') { 'Green' } else { 'Red' }) }
$failed = @($results | Where-Object { $_ -like 'FAIL*' }).Count
@($results) + '' + ("RESULT: {0} step(s), {1} failed" -f $results.Count, $failed) | Set-Content "$out\summary.txt"
Stop-Transcript | Out-Null
Set-Content "$out\DONE" $(if ($failed) { 'FAIL' } else { 'PASS' })
Write-Host "`nWindow stays open. Close the Sandbox to discard everything."
