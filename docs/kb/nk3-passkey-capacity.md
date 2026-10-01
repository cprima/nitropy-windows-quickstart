# Nitrokey 3: estimating how many passkeys still fit

How to estimate the remaining passkey capacity from the `Free blocks (int)` counter in `nitropy nk3 status`. See also `nk3-free-blocks.md` for what the counters mean.

## Measurement so far

NK3, LPC55, revision 2, firmware v1.9.1:

| When | Free blocks (int) |
|---|---|
| Before upgrading the GitHub registration to a passkey | 48 |
| After the upgrade | 42 |

One passkey changed the internal counter by 6 blocks. This is a single data point.

## Prediction

Internal free space is 42 blocks.

- If every passkey costs 6 blocks: 42 / 6 = about 7 more passkeys.
- If the first passkey paid a one-time overhead (FIDO app files, counters) and the marginal cost is 2 to 3 blocks: about 14 to 21 more passkeys.

So the estimate is roughly 7 to 20 more passkeys.

## Second data point: tool estimate and a test credential

After a test credential was registered on webauthn.io, `Free blocks (int)` was still 42. A tool then reported:

> There is an estimated amount of 11 credential slots left

The tool that printed this was not recorded, and how it computes the number is not known. It is an estimate, not a count of real slots.

Reading it against the free-block counter: 42 blocks / 11 slots is about 3.8 blocks per credential. That sits between the two cases above (6 blocks per credential gave 7 slots; 2 to 3 blocks gave 14 to 21), so the revised working estimate is **about 11 more credentials**.

### Result after deleting the test credential

- The webauthn.io credential was resident: `nitropy fido2 delete-credential` found and deleted it on the key.
- `Free blocks (int)` was 42 with the credential present and still 42 after deleting it. The counter did not track that credential.
- `nitropy fido2 list-credentials` then listed two resident credentials, GitHub and Google. The Google credential was registered while its security delay was still pending, and it also left the counter at 42.
- The same `list-credentials` run ended with "There is an estimated amount of 11 credential slots left". So that message comes from `list-credentials`, and it was printed with 2 credentials stored.

Conclusions:
- `Free blocks (int)` is a poor measure of per-credential cost here: resident credentials were added and removed without changing it. Only the first passkey (48 to 42) moved it, which fits a one-time overhead.
- The "11 slots left" figure is an estimate whose method is not documented here. It is probably derived from free space, since it stayed at 11 while credentials were added and removed. This is a guess.
- To know how many credentials are stored, count them with `list-credentials`. Do not infer it from the block counter.
- The firmware may enforce its own cap on stored credentials, separate from free blocks. That cap is not known here.

## Deleting a test credential

Resident credentials on the key can be listed and deleted with nitropy (the FIDO2 PIN is required):

```
just nitropy fido2 list-credentials
just nitropy fido2 delete-credential --cred-id <credential-id>
```

`list-credentials` prints each credential's relying party, user and ID. Pass that ID to `--cred-id`. Run `just status` afterwards and check that `Free blocks (int)` is back to its earlier value.

## Why the estimate is uncertain

- One data point cannot separate fixed overhead from per-passkey cost.
- The 6 blocks may include the removal of the old plain security-key entry or filesystem write overhead.
- OTP secrets share the same internal space.
- The firmware may enforce its own limit on the number of passkeys, independent of free blocks. The limit for v1.9.1 is not known here.

## How to measure the marginal cost

1. Run `just status` and note `Free blocks (int)`.
2. Register one more passkey on a throwaway site (for example webauthn.io), not on a real account.
3. Run `just status` again. The difference is the marginal cost per passkey.
4. Remaining capacity is the remaining free blocks divided by the marginal cost.
5. Delete the test credential and check that the counter returns to the earlier value.

## Practical note

For a few accounts, 42 free blocks is plenty. The limit matters only if many accounts move to passkeys on one key. Passkeys cannot be exported, so keep a second authentication method on every account (TOTP seed in a password manager, recovery codes, or a second key).
