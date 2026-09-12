# ADR 001: Desktop Updater Trust — Deferred Until Signature Verification Ships

Date: 2026-09-12
Status: Accepted
Deciders: OpenAccounting maintainers

## Context

The desktop auto-updater fetches release artifacts over HTTPS from GitHub Releases.
Without cryptographic binding between the artifact bytes and a pinned trust root,
an attacker who compromises the release distribution can ship arbitrary binaries
even if TLS is valid. The review (2026-09-12, REVISE, P1) flagged that
`desktop_updater.dart:151` lacked enforced signature verification and that
installation could proceed via `auto_updater` without verifying the exact
downloaded bytes.

A correct updater needs:

- A trust root (Ed25519 public key) pinned in the binary or OS keychain.
- A signature over the artifact bytes + version, verified before any install
  hand-off.
- No `caller-supplied quiesce`: the updater itself must gate installation,
  not trust the caller to have verified.

No trust root is currently shipped, and no signing pipeline is reviewed.

## Decision

Defer automatic installation until the above trust is implemented.
Until then the updater operates in **deny-all** mode:

- `GithubUpdateBackend.verifySignature()` always returns `false`
  (`// ponytail: no trust root shipped — deny all`).
- `DesktopUpdaterServiceImpl.downloadUpdate()` verifies and throws
  `StateError('Update-Signatur ungültig')` on any non-verified artifact,
  clearing both `_downloadedInfo` and `_verifiedInfo`.
- `installAndRestart()` requires `_verifiedInfo != null` and a bound
  `_downloadedArtifact`; with the current backend it always throws
  `StateError('No verified update artifact is ready')` or
  `UnsupportedError` about the hand-off not being configured.
- The factory `createDesktopUpdaterService(enabled: false)` ships disabled
  by default; VM tests inject `enabled: true` with a fake backend.

This is the smallest safe fix that closes the trust hole without adding a
half-reviewed crypto path. The code remains so the future verifier can bind
the exact bytes it checks to the install operation, but it cannot install.

## Alternatives Considered

- **Ship a quick HMAC check**: rejected — symmetric secret cannot be shipped
  in an AGPL binary without exposure; asymmetric (Ed25519) is required.
- **Remove updater code entirely**: deferred — keeping the deny-all gate
  preserves the download→verify→install shape for the future, with zero
  additional risk. Full removal is tracked as a follow-up if the trust root
  decision slips beyond the next release.

## Consequences

- Desktop users must update manually until the signed pipeline ships.
- Any artifact without a valid Ed25519 signature is rejected; no downgrade
  or bypass is possible via caller flags.
- Future work: pin Ed25519 public key in `desktop_updater.dart`,
  verify `signature` over artifact bytes + version in
  `GithubUpdateBackend.verifySignature`, and wire `auto_updater` to the
  exact verified file. See `ponytail: upgrade path` comment in code.

## Verification

- `test/features/desktop/update_test.dart` expects rejection of bad
  signatures and success only with a fake backend that returns `verifyResult: true`.
- `test/integration/audit/infra-hardening_test.dart` asserts that
  `GithubUpdateBackend.verifySignature` denies an arbitrary signature,
  that `downloadUpdate` with a bad signature throws, and that
  `installAndRestart` without verification throws.

## References

- lib/features/desktop/desktop_updater.dart:50-170
- docs/superpowers/ (review verdict 2026-09-12)
