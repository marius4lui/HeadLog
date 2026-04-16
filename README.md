# HeadLog

HeadLog is a fast, offline-first headache tracker built for moments where speed matters more than workflow. The app is designed around instant logging: one tap creates one entry, repeated rapid taps create repeated entries, and richer details stay optional.

## Why HeadLog

Most symptom trackers slow the user down with forms, confirmations, and too many decisions up front. HeadLog takes the opposite approach:

- Instant 1-tap headache logging
- Rapid repeat taps with no debounce
- Optional intensity, causes, and notes
- Local-first storage with no account required
- Fast review of daily patterns and recent entries

The result is a tracker that stays usable even when the user is already in pain.

## Features

- Material 3 Flutter app with light and dark mode
- Instant log button with haptic feedback
- Quick intensity presets including `Light`, `Medium`, `Strong`, and `Extreme`
- Expanded composer for optional causes and additional context
- Recent entries timeline with swipe-to-delete
- Daily overview, mini day summary, week/month calendar views
- Local persistence via `sqflite`
- Android release pipeline via GitHub Actions
- Optional Cloudflare Worker for private-release APK delivery

## Screens at a Glance

HeadLog is structured around three core interactions:

1. Log immediately from the main screen
2. Add optional detail only when needed
3. Review entries and patterns without leaving the primary flow

## Tech Stack

- Flutter stable
- Dart with null safety
- Riverpod for state management
- `sqflite` for local persistence
- GitHub Actions for Android release automation
- Cloudflare Workers for optional APK proxy delivery

## Project Structure

```text
lib/
  models/
  screens/
  services/
  theme/
  viewmodels/
  widgets/

android/
ios/
test/

.github/workflows/
  release-android.yml
```

## Getting Started

### App

```bash
flutter pub get
flutter run
```

### Tests and checks

```bash
flutter analyze
flutter test
```

## Android Releases

HeadLog includes an automated Android release workflow.

When you push a git tag like `v1.1`, `v1.2`, or `v2.0.0`, GitHub Actions will:

- install Flutter
- run `flutter analyze`
- run `flutter test`
- build the release APK
- create a GitHub Release
- attach the generated APK to that release
- generate a release description from recent commits

Example:

```bash
git tag v1.1
git push origin v1.1
```

Workflow file:

- [release-android.yml](./.github/workflows/release-android.yml)

More details:

- [docs/RELEASES.md](./docs/RELEASES.md)

## Downloading APKs from Releases

There are two supported ways to distribute Android builds:

### 1. Directly from GitHub Releases

Each version tag creates a GitHub Release with the APK attached.

This is the simplest distribution path for development and internal sharing.

### 2. Through the optional Cloudflare Worker

The repository includes a Worker project under `headlog/` that can proxy APK downloads from a private GitHub repository.

That is useful when:

- the GitHub repo is private
- you still want a public or controlled download URL
- you want a stable endpoint like `/download/latest` or `/download/v1.1`

More details:

- [docs/DOWNLOADS.md](./docs/DOWNLOADS.md)

## Cloudflare Worker Overview

The Worker under `headlog/` can:

- fetch the latest release from GitHub
- fetch a tagged release such as `v1.1`
- locate the APK asset in that release
- stream the APK back as a downloadable file

Configured endpoints include:

- `/download`
- `/download/latest`
- `/download/v1.1`

The Worker expects:

- `GITHUB_OWNER`
- `GITHUB_REPO`
- `APK_ASSET_NAME`
- `DEFAULT_TAG`
- `GITHUB_TOKEN` as a Wrangler secret

## Privacy

HeadLog is designed around local-first usage.

- entries are stored on-device
- no login is required
- no remote app backend is needed for the core tracking flow

The optional Cloudflare Worker is only for APK distribution and is not part of the headache data flow.

## Roadmap Direction

The codebase is intentionally set up to support future additions such as:

- export to CSV
- widgets / quick actions
- background logging shortcuts
- richer trend views

## Repository Notes

- Android min SDK is `23`
- iOS project is included
- the Cloudflare Worker lives in `/headlog`
- local secrets for the Worker should never be committed

## License

No license file is currently included. Add one before public open-source distribution if you want to define reuse terms explicitly.
