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
- **M4, localization and theming.** English, German and Chinese UI plus a "System default"
  language option. Strings live in ARB fragments (`lib/l10n/src/*.json`) that
  `dart run tool/merge_arb.dart` merges into `lib/l10n/arb`; the `flutter gen-l10n` output is
  committed in `lib/l10n/gen`. Inter is bundled as the app font. Design tokens, Material You
  dynamic color, and appearance settings for contrast, density and reduced motion. No glass
  effects.
- **M5, app shell and task UI.** Five-tab shell (Today, Inbox, Upcoming, Projects, More) with a
  navigation rail on wide screens. Task tile with swipe actions, bulk selection, undo and
  inline edit. Quick-add sheet with natural-language parsing (English, German, Chinese) and
  recurrence. Today, Focus and Daily review screens, smart lists, and restyled inbox, Kanban
  and notes.
- **M6, search and task detail.** Global search with an offline fallback, a command palette
  (Ctrl/Cmd+K), redesigned task detail and edit screens, a recurrence editor, subtasks, and
  `tududa://` deep links.
- **M7, Android widget.** Home-screen widget built with Glance and Material You, a quick-add
  modal activity opened from the widget's "+", Kotlin session and widget bridges to Flutter,
  a Tink-backed vault shared with the app, and a widget reconciler that applies widget
  completions to the local database.
- **M8, quality.** Accessibility test suite, performance tests, and CI-only alchemist golden
  tests (`test/goldens`, `golden` tag). CI now checks that generated localizations are fresh,
  runs the widget bridge integration test and the Android instrumented tests on the emulator,
  and reports cold start time.

### Known limitations

- Subtask order can be changed in the UI but is not persisted.
- Yearly recurrence is not supported by the server.
- The widget needs one fresh sign-in after upgrading so the credentials are stored in the vault.
- Golden tests run in CI only (they are deterministic there and not meant for local platforms).
- Instrumented tests (`:app:connectedDebugAndroidTest`, `integration_test`) are wired into the
  emulator job but not yet proven in CI; they do not gate releases. See the README roadmap.

### Changed

- Database schema v2 adds indexes for common queries (M8).
- Default route is `/today`, inside the new five-tab shell (M5).
- Areas use the plural `/api/areas` endpoints.
- Sign-out uses `GET /api/logout`.

### Fixed

- Accessibility fixes found by the new a11y suite (M8).
- Editing a note now addresses it by `uid`.

### Security

- The widget and the app share one Tink-encrypted vault (credentials, cookies, board cache,
  change log); signing out wipes it. The native session bridge hands credentials back only to
  the Dart silent re-login path (M7).

### Removed

- The old monolithic `ApiService`, replaced by the typed API/repository layer.

## [1.0.1] - 2026-04-28

### Changed

- App version bumped to 1.0.1; task status management improved.
- Release workflow can create a release from a manual run with a custom tag.
