# Contributing to JourneySync

Thank you for your interest in contributing.

## Ground Rules

- Keep changes focused and reviewable.
- Prefer small pull requests with clear scope.
- Include reasoning for behavior changes.
- Avoid unrelated formatting-only changes in feature PRs.

## Development Setup

1. Install Flutter SDK (stable channel).
2. Clone the repository.
3. Run:

```bash
flutter pub get
flutter analyze
flutter test
```

## Branch and Commit Guidelines

- Branch naming examples:
  - `feature/nearby-ride-filter`
  - `fix/login-rls-error-handling`
  - `docs/readme-refresh`
- Commit message style (recommended):
  - `feat: add ride join guard`
  - `fix: handle missing avatar_url column`
  - `docs: add security policy`

## Pull Request Checklist

Before submitting a PR:

- [ ] App builds locally.
- [ ] `flutter analyze` passes.
- [ ] Relevant tests pass or are added.
- [ ] UI changes include screenshots/video when applicable.
- [ ] Documentation is updated for behavior changes.

## Code Style

- Follow lint rules in `analysis_options.yaml`.
- Prefer descriptive names over short abbreviations.
- Keep widgets and service methods focused.
- Add comments only where behavior is non-obvious.

## Issue Reporting

When opening an issue, include:

- Expected behavior
- Actual behavior
- Steps to reproduce
- Device/OS and app version
- Logs/screenshots when relevant

## Feature Proposals

For feature requests, include:

- User problem
- Proposed solution
- Alternatives considered
- Impacted screens/services

## Security

Do not open public issues for sensitive vulnerabilities.
Use the process in `SECURITY.md`.
