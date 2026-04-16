# Releases

This project ships Android builds through GitHub Releases.

## How it works

The workflow at `.github/workflows/release-android.yml` runs whenever a version tag matching `v*` is pushed.

Examples:

- `v1.1`
- `v1.2`
- `v2.0.0`

For each release tag, the workflow:

1. checks out the repository
2. installs Flutter
3. runs static analysis
4. runs tests
5. builds the release APK
6. creates a GitHub Release
7. attaches the APK artifact to that release

## Creating a release

```bash
git tag v1.1
git push origin v1.1
```

## Release notes

The workflow builds a release body from commits since the previous `v*` tag and also enables GitHub-generated release notes.

## APK output

The Android APK attached to the release is built from:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Requirements

- GitHub Actions enabled for the repository
- permission to create releases
- healthy Flutter build on the tagged commit

## Common failure points

- failing tests
- analyzer issues
- invalid Android signing/release build state
- a tag pushed from a commit that does not build cleanly
