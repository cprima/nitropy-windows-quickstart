# pynitrokey on Windows: a setup that works

A tested way to run [pynitrokey](https://github.com/Nitrokey/pynitrokey) (`nitropy`) on Windows 11 with [uv](https://docs.astral.sh/uv/) and [just](https://just.systems/), without touching `PATH` and without a global install.

This repo holds **no pynitrokey source**: it is a uv project that installs pynitrokey from PyPI, plus recipes that smooth over the Windows rough edges. Unofficial, not affiliated with Nitrokey.

Nitrokey's [installation docs](https://docs.nitrokey.com/software/nitropy/all-platforms/installation) say: *"For Windows users: Windows support is still experimental – please use with caution. You can also use pre-compiled binaries or a MSI installer, see Installing nitropy on Windows."* This repo is a third route for people who prefer a pip/uv install: a worked example that it runs fine from PyPI with the setup below. It does not replace the official installer.

## The Windows problem

On Windows, `nitropy` cannot reach a Nitrokey 3 or Nitrokey FIDO2 over HID from a normal shell. It prints:

```
Warning: It is recommended to execute nitropy with admin privileges to be able to access Nitrokey 3 and Nitrokey FIDO 2 devices.
Critical error:
No Nitrokey 3 device found
```

Run from an elevated shell, the same command works. The recipes here make that automatic: when the shell is not elevated they re-run `nitropy` with admin rights (one UAC prompt):

- **Windows 11 with `sudo` in Inline mode:** through `sudo --inline`, output stays in your terminal.
- **Windows 10, or `sudo` missing or not inline:** through a UAC-elevated PowerShell window. Prompts such as `[y/N]` are answered in that window; the output is relayed to your terminal when it closes.

## Prerequisites

- Windows 10 or 11. Recommended on Windows 11: enable `sudo` in **Inline** mode (Settings > System > For developers) so output stays in your terminal. Without it, the UAC-window fallback is used.
- `uv` and `just`: `winget install astral-sh.uv Casey.Just`
- The Microsoft Visual C++ runtime, which `just` needs. Most PCs already have it; a fresh Windows may not (see Troubleshooting). `winget install Microsoft.VCRedist.2015+.x64`

Python is not a prerequisite: uv downloads Python 3.12 itself. It is pinned (`.python-version`, and `requires-python` in `pyproject.toml`) because pynitrokey's `hidapi` dependency has Windows wheels only up to Python 3.12. On a newer Python it would try to compile and fail without the Visual C++ Build Tools. The recipes also override a global `UV_PYTHON` for that reason.

## Quick start

```
git clone https://github.com/cprima/nitropy-windows-quickstart
cd nitropy-windows-quickstart
just sync     # create .venv, install pynitrokey
just doctor   # verify uv, venv, sudo mode, admin, device visible
just status   # Nitrokey 3 status (UAC prompt)
```

`just` lists all recipes. Anything else: `just nitropy <args>`, e.g. `just nitropy nk3 secrets list`.

## Recipes

| Recipe | Purpose |
|---|---|
| `doctor` | check uv, venv, pynitrokey, admin/sudo mode, device visible over HID |
| `nitropy <args>` | run `nitropy`, elevating when needed (sudo, else UAC window) |
| `install-shim` / `uninstall-shim` | **optional**: add or remove a `nitropy` command on your user PATH (see below) |
| `status`, `wink`, `test`, `secrets-list` | Nitrokey 3 shortcuts (`wink` blinks the LED) |
| `fw-check` | compare device firmware with the latest release, no flashing |
| `snapshot` | save status and versions to `snapshots/` (gitignored, contains the device UUID) |
| `fw-update` | snapshot, then flash the latest stable firmware (asks to confirm) |
| `factory-reset` | snapshot, then **erase everything** on the key (asks to confirm) |
| `upgrade`, `pin <ver>`, `unpin` | change the pynitrokey version, then run `doctor` |
| `last-log` | print the newest nitropy crash log from `%TEMP%` |

Never unplug the key during `fw-update`. `factory-reset` cannot be undone.

## Optional: `nitropy` on PATH

Nothing needs PATH; `just nitropy ...` works from this folder. If you want to type plain `nitropy` from anywhere:

```
just install-shim     # asks first
just uninstall-shim   # removes it again
```

This writes one small `nitropy.cmd` to `%LOCALAPPDATA%\nitropy-quickstart\bin` and adds only that folder to your user PATH. The venv is not added, so its `python`/`pip` never shadow anything. The shim calls the same elevation logic as the recipes. Open a new terminal afterwards.

## Troubleshooting

- **`just` prints nothing and exits with `0xC0000135` (-1073741515)**: the Visual C++ runtime is missing. Install it: `winget install Microsoft.VCRedist.2015+.x64`, or https://aka.ms/vs/17/release/vc_redist.x64.exe
- **`Microsoft Visual C++ 14.0 or greater is required` during `just sync`**: uv used a Python newer than 3.12 and is trying to build `hidapi`. Run `just sync` from this folder so the pinned version is used, and check for a conflicting `UV_PYTHON` or `uv sync --python` elsewhere.
- **"No Nitrokey 3 device found"**: not elevated, or the key is behind a hub. Run `just doctor`.
- **"no backend was found"**: a libusb warning, only relevant for bootloader mode and legacy devices. Harmless for a Nitrokey 3 in normal mode.
- **sudo in "Force New Window" mode**: not usable for in-terminal output, so the UAC-window fallback is used instead. Switch sudo to Inline to avoid the extra window.
- **Crash log**: `just last-log`. Support: https://support.nitrokey.com/

## Verified

Windows 11, Nitrokey 3 (LPC55), pynitrokey 0.14.0: `nk3 status`, `nk3 test` (UUID, version, status, SE050, FIDO2), and a firmware update v1.9.0 to v1.9.1 all worked through these recipes, using the Windows 11 inline-sudo path. A fresh Windows Sandbox run (`sandbox/quickstart.wsb`, a clean Windows with no tools installed) passes all 14 steps: install of uv and just, `just sync` on Python 3.12, `just doctor` (without a device, since Sandbox has no USB), and the PATH shim install, run and uninstall. It also found the two prerequisites above. The non-admin path (UAC prompt, then `sudo --inline`) is verified on the Windows 11 machine with a Nitrokey 3 attached (`just status`). Not yet verified: the Windows 10 / UAC-window fallback, and the non-admin path on a clean machine (the Sandbox user is already an administrator). Other Nitrokey models are untested; the shortcut recipes are NK3-specific, but `just nitropy <args>` works for any command.

## License

[Apache-2.0](LICENSE). Covers the files in this repository only; pynitrokey itself is installed from PyPI under its own licenses.
