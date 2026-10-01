set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]

# .python-version is the single source of truth; export it so a global UV_PYTHON cannot override it
export UV_PYTHON := trim(read(".python-version"))

default:
    @just --list

# --- setup -----------------------------------------------------------------

# create/update venv from pyproject.toml + uv.lock
sync:
    uv sync

# upgrade pynitrokey to latest release, then run doctor
upgrade:
    uv lock --upgrade-package pynitrokey
    uv sync
    @just doctor

# pin pynitrokey to an exact version, e.g. `just pin 0.14.0`
pin version:
    uv add "pynitrokey=={{version}}"
    @just doctor

# remove the version pin (back to latest allowed)
unpin:
    uv add pynitrokey
    @just doctor

# check uv, venv, pynitrokey, sudo mode, admin and device visibility
doctor:
    @powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1

# --- nitropy ---------------------------------------------------------------

# run nitropy with any args, e.g. `just nitropy nk3 status`; if not admin: inline sudo (Win 11), else UAC window (Win 10)
nitropy *args:
    @powershell -NoProfile -ExecutionPolicy Bypass -File scripts/nitropy.ps1 {{args}}

# OPTIONAL: add a `nitropy` command to your user PATH (a tiny shim; the venv itself is not added)
[confirm("Add a nitropy.cmd shim to %LOCALAPPDATA%\\nitropy-quickstart\\bin and that folder to your user PATH?")]
install-shim:
    @powershell -NoProfile -ExecutionPolicy Bypass -File scripts/shim.ps1 install

# undo install-shim (removes the shim and its PATH entry)
uninstall-shim:
    @powershell -NoProfile -ExecutionPolicy Bypass -File scripts/shim.ps1 uninstall

# show installed pynitrokey version
version:
    uv run nitropy version

# list connected Nitrokey devices
list:
    @just nitropy list

# --- NK3 shortcuts ---------------------------------------------------------

# NK3: device status
status:
    @just nitropy nk3 status

# NK3: blink the LED (find which key is which)
wink:
    @just nitropy nk3 wink

# NK3: run the built-in self-tests (asks for touch)
test:
    @just nitropy nk3 test

# NK3: list registered OTP credentials
secrets-list:
    @just nitropy nk3 secrets list

# NK3: compare device firmware with the latest release (no flashing)
fw-check:
    @powershell -NoProfile -ExecutionPolicy Bypass -File scripts/fw-check.ps1

# NK3: save status + versions to snapshots/ (gitignored)
snapshot:
    @powershell -NoProfile -ExecutionPolicy Bypass -File scripts/snapshot.ps1

# NK3: update firmware to latest stable (snapshots first, asks to confirm)
[confirm("Flash the latest NK3 firmware? Do not unplug the key during the update.")]
fw-update:
    @just snapshot
    @just nitropy nk3 update

# NK3: FACTORY RESET - erases all credentials and keys on the device
[confirm("This ERASES everything on the NK3 (keys, credentials, PINs) and cannot be undone. Continue?")]
factory-reset:
    @just snapshot
    @just nitropy nk3 factory-reset

# --- troubleshooting -------------------------------------------------------

# print the newest nitropy crash log
last-log:
    @$f = Get-ChildItem $env:TEMP -Filter 'nitropy-*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1; if ($f) { $f.FullName; ''; Get-Content $f.FullName } else { 'no nitropy logs in ' + $env:TEMP }
