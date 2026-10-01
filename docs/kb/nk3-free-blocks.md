# Nitrokey 3: what "Free blocks" means in `nk3 status`

`nitropy nk3 status` (or `just status`) prints two free-space counters:

```
Free blocks (int):  42
Free blocks (ext):  470
```

## Meaning

They show how much space is left in the NK3's flash filesystem. The unit is filesystem blocks, not bytes. The exact block size is not confirmed here.

| Counter | Storage | Notes |
|---|---|---|
| `int` | Flash inside the main chip (LPC55) | Small. Credentials, passkeys and app data live here. This is the number to watch. |
| `ext` | Separate external flash chip | Much larger. Not affected by normal passkey use. |

## Observed on this device

NK3, LPC55, revision 2, firmware v1.9.1:

| When | int | ext |
|---|---|---|
| Before registering a GitHub passkey | 48 | 470 |
| After upgrading the GitHub registration to a passkey | 42 | 470 |

The internal count dropped by 6 and the external count did not change. The link to the passkey is inferred from the timing; it was not measured in isolation.

## What uses space

- Passkeys (FIDO2 resident credentials): use internal blocks, roughly 6 per credential as observed above (a single data point, so treat it as a rough guide).
- Plain FIDO2 security keys used as a second factor: use no space on the key, because the site stores the credential data.
- OTP secrets (TOTP/HOTP entries in the secrets app): also use internal space.

## What to do when space runs low

- Check the counter after adding credentials: `just status`.
- List stored OTP entries: `just secrets-list` (`nitropy nk3 secrets list`), and remove entries you no longer use.
- Track the number over time: `just snapshot` saves the status output to `snapshots/` (gitignored, local only).
- A factory reset frees everything, but it erases all credentials and passkeys and cannot be undone. Use it only as a last resort.

## Related

- The FIDO2 PIN is one PIN per key. Eight wrong attempts in a row lock the FIDO2 app, and only a factory reset recovers it.
- Passkeys on the key cannot be exported or backed up. Keep a second authentication method (TOTP seed in a password manager, recovery codes, or a second key) on every account.
