# HeadLog

HeadLog is a minimal, offline-first headache tracker designed around instant logging. Every tap creates a new entry immediately, including rapid repeated taps, so it stays useful when speed matters more than setup.

## Features

- One-tap headache logging with haptic feedback
- Rapid repeated taps with no debounce
- Material 3 light and dark themes
- Local persistent storage with `sqflite`
- Quick intensity presets: light, medium, strong
- Recent entry history with swipe to delete
- Daily count stats for fast trend checking

## Tech Stack

- Flutter stable
- Dart with null safety
- Riverpod for state management
- `sqflite` + `path_provider` for local persistence

## Project Structure

```text
lib/
  models/
  screens/
  services/
  theme/
  viewmodels/
  widgets/
```

## Run

```bash
flutter pub get
flutter run
```

## Notes

- Android min SDK is set to 23.
- The app stores all entries locally and works offline.
- The current architecture leaves room for future widget support, export, and background logging features.
