# JourneySync release report

Date: 2026-10-31

The authoritative version, build metadata, APK checksum, commit, CI result, and
deployment checks are produced by `scripts/ship-change.ps1`. This document does
not pre-state those values before the verified artifact exists.

## Release contents

- Categorised Get Help entry flow
- Medical, breakdown, separated, and general assistance context
- Explicit JourneySync-versus-112 safety explanation
- Backward-compatible alert persistence without a schema change
- Landing safety copy aligned to actual capabilities
- Unsupported automatic crash-detection claim removed
- Required audit, security, parity, test, release, and improvement documents

## Gate

The signed sideload APK may be published only after the release script verifies
formatting, analysis, tests, landing checks, package ID, version, signature,
file identity, CI, and deployed APK length/version.
