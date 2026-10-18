# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **M1, foundation.** Flutter toolchain pinned to 3.47.7 via `environment.flutter` in
  `pubspec.yaml` (CI reads it with `flutter-version-file`). Stable router instance that no
  longer rebuilds on auth changes. Debug logs redact credentials, cookies and CSRF tokens.
  CI baseline: `pub get --enforce-lockfile`, format check, `flutter analyze --fatal-infos`,
  tests with coverage, debug build.
- **M2, API layer.** Typed API and repository layer with DTOs. CSRF handling (the
  `x-csrf-token` header on mutating requests, fetched lazily and refreshed once on a
  CSRF 403) and silent re-login on 401. Session lifecycle with a credential store.
- **M3, offline-first.** Drift (SQLite) store as the single source of truth for the UI, with
  an outbox of pending writes, a sync engine (pull, then push with retry and backoff),
  field-level three-way merge for conflicting edits, and a sync status UI.
- **M7-core, Android widget groundwork.** Shared Kotlin library `:tududi_core`: a
  Tink-encrypted vault for credentials and cookies, and an API client with CSRF handling
  and silent re-login. Android `minSdk` set to 26.
- **M8, CI and docs.** CI jobs for Android unit tests, APK builds, gitleaks and OSV
  scanning, and an emulator smoke test. Dependabot configuration. Hardened release
  workflow (tests before build, keystore kept outside the workspace, signature check,
  SHA-256 checksum, separate debug-symbol artifact, notes taken from this file). Rewritten
  README files and `docs/architecture.md`.

### Changed

- Areas use the plural `/api/areas` endpoints.
- Sign-out uses `GET /api/logout`.

### Fixed

- Editing a note now addresses it by `uid`.

### Removed

- The old monolithic `ApiService`, replaced by the typed API/repository layer.

## [1.0.1] - 2026-04-28

### Changed

- App version bumped to 1.0.1; task status management improved.
- Release workflow can create a release from a manual run with a custom tag.
