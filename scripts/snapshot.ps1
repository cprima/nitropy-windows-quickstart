. "$PSScriptRoot\lib.ps1"

$dir = Join-Path $PSScriptRoot '..\snapshots'
New-Item -ItemType Directory -Force $dir | Out-Null
$file = Join-Path $dir ("nk3-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

$lines = @("date: $(Get-Date -Format o)")
$lines += (uv pip list 2>$null | Select-String '^pynitrokey\s').Line
$lines += Invoke-Nitropy nk3 status 2>&1 | ForEach-Object { "$_" }
$lines | Out-File -Encoding utf8 $file

Get-Content $file
Write-Host "`nsaved: $((Resolve-Path $file).Path)" -ForegroundColor Green
