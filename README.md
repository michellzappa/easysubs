# EasySubs for macOS

A tiny native macOS app that recreates the old drag-and-drop subtitle workflow:

1. Drop a video onto the window.
2. The app fingerprints it and searches OpenSubtitles in your chosen language.
3. The best subtitle is downloaded as `Video filename.srt` beside `Video filename.mkv`.

Multiple files can be dropped together. Existing `.srt` files are kept unless replacement is enabled in Settings.

## One-time OpenSubtitles setup

The current OpenSubtitles REST API requires credentials that the older service did not:

1. Create or use a free [OpenSubtitles.com account](https://www.opensubtitles.com/en/users/sign_up).
2. Create an API consumer/key from the [API consumers page](https://www.opensubtitles.com/en/consumers).
3. Enter the username, password, API key, and preferred subtitle language in the app.

The password is stored in macOS Keychain. The API key, username, language, and replacement preference are stored in the app's local preferences.

## Build

The checked-in Xcode project can be opened directly:

```sh
open EasySubs.xcodeproj
```

Or regenerate it after editing `project.yml`:

```sh
xcodegen generate
```

The app targets macOS 14 or newer and has no third-party runtime dependencies.

## Regenerate the app icon

The complete macOS icon set is drawn in code with AppKit/Core Graphics—there are no external design files or image-generation dependencies:

```sh
swift scripts/generate-icon.swift
```

The script writes all required 1x and 2x PNG variants into the `AppIcon.appiconset` asset catalog. It renders the same `captions.bubble.fill` SF Symbol used in the EasySubs header so the app and Dock icon match exactly.

## Matching behavior

The app first computes the standard OpenSubtitles hash from the video's first and last 64 KiB plus its size. This generally identifies the exact release and timing. If no hash match exists, it falls back to the full video filename and chooses the most-downloaded result returned by OpenSubtitles.
