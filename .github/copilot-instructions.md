# JourneySync release instructions

Read and follow the repository-root `AGENTS.md` for every task. Production code
changes are not complete until the app and landing checks pass, the signed APK
has replaced `landing/public/journeysync.apk`, intended changes are pushed, CI is
green, and the deployed download is verified. Use `scripts/ship-change.ps1` for
the release workflow and semantic version synchronization. Never expose secrets.
