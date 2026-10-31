# JourneySync test report

Date: 2026-10-31

## Automated checks

The release workflow is the final authority for command results. It executes:

- landing text encoding verification
- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze`
- `flutter test`
- landing ESLint and production build
- signed sideload APK build
- APK package/version/signature/hash validation
- Git diff whitespace and secret-path checks

Added regression coverage verifies all four assistance categories round-trip
through the existing alert message contract and that legacy generic SOS rows
remain readable as general assistance.

## Not executed in this workspace

- Physical-device background/force-stop/reboot tests
- OEM battery restriction matrix
- Two-account staging workflows and push delivery
- Privileged production RLS catalog tests
- Live emergency call completion (the UI opens the system dialer only)
- Full visual screenshot matrix for every Flutter screen

These items are NOT VERIFIED and must not be inferred from a successful build.
