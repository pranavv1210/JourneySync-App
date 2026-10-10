# JourneySync agent release contract

These instructions apply to every AI coding agent working in this repository.

## Version source of truth

- `pubspec.yaml` is authoritative. Keep the public version synchronized in
  `lib/services/app_version.dart`, the geocoding user-agent, landing-page copy,
  and APK cache-busting URLs.
- Use semantic versioning: `patch` for fixes and presentation-only changes,
  `minor` for backward-compatible product features, and `major` for breaking
  product or data-contract changes. A major bump moves `1.x.x` to `2.0.0`.
- Do not invent a version. Use `scripts/ship-change.ps1 -Bump <level>`.

## Definition of done for production changes

Unless the user explicitly asks for local-only work or says not to release,
do not stop after editing code. Before declaring a production change complete:

1. Preserve unrelated user changes and inspect the complete diff for secrets.
2. Run formatting, Flutter analysis/tests, and landing lint/build as applicable.
3. Build the signed sideload release APK with the existing signing identity.
4. Copy the verified APK to `landing/public/journeysync.apk`.
5. Verify package ID, version, signature, file size, and SHA-256 checksum.
6. Commit and push the intended changes without force-pushing.
7. Wait for GitHub Actions to finish successfully.
8. Verify the deployed landing page and APK URL return the intended version.

For the normal end-to-end workflow, use:

```powershell
.\scripts\ship-change.ps1 -Bump patch -Message "fix(scope): describe change"
```

Use `-Bump none` only when the user explicitly requires the current public
version to remain unchanged. The script automates checks, version synchronization,
APK publication into the landing app, commit, and push. A script cannot detect a
prompt by itself; this file is the durable instruction that tells compatible
agents to run the workflow after making changes.

Never print or commit `.env`, signing keys, tokens, or `dart_defines.local.json`.
