# Subs

A minimal native macOS menu-bar app that gets subtitles for a video. Drop a
video, get its `.srt` beside it.

Drop one or more videos on the menu bar icon, or on the drop window that opens
from the menu. Subs fingerprints each video, searches OpenSubtitles in your
language, and saves the best subtitle as `Video name.srt` beside
`Video name.mkv`. The icon dims while it works. The menu lists the recent
videos; click one to show its subtitle in Finder.

Subs was called EasySubs. On first launch it copies the EasySubs settings and
the Keychain password.

## Requirements

- macOS 14 (Sonoma) or later
- A free [OpenSubtitles.com account](https://www.opensubtitles.com/en/users/sign_up)
  and an API key from the [API consumers page](https://www.opensubtitles.com/en/consumers).
  The current REST API needs both: searching needs the key, downloading needs
  a signed-in account.

## Build

```sh
./scripts/build-app.sh      # → /Applications/Subs.app, signed, icon regenerated
```

Needs `xcodegen`. [HouseKit](https://github.com/michellzappa/housekit), pinned to a
release tag in `project.yml`, supplies the menu bar plate, the app icon, the settings window
and launch at login: the pieces Subs shares with Clip, Tessellate and Cargo.
To work in Xcode instead: `xcodegen generate && open Subs.xcodeproj`.

Signing uses the stable Apple Development identity from `project.yml`.
Keychain ties its access grant to the code signature, and an ad-hoc build
asks for the password again after every rebuild. Set your own
`DEVELOPMENT_TEAM` first.

### Downloadable releases

Push a tag matching `CFBundleShortVersionString` (e.g. `v0.1.0`) to run
`.github/workflows/release.yml`: universal build, Developer ID signature,
notarization, a ZIP plus `SHA256SUMS` on the GitHub Release. Same secrets as
Clip's workflow (`APPLE_TEAM_ID`, the Developer ID certificate, an App Store
Connect API key).

## Configuration

Settings opens from the menu bar item (⌘,):

- **General**: launch at login.
- **Subtitles**: language, and whether to replace an existing `.srt`.
- **OpenSubtitles**: username, password, API key.
- **About**: version, changelog, source.

The password is stored in macOS Keychain. The API key, username, language and
the replace setting are stored in the app's preferences.

## Architecture

AppKit status item, SwiftUI settings and drop window. No dependencies beyond
`HouseKit` and this repo's own `EasySubsKit`.

| | |
| --- | --- |
| `EasySubsKit` (`Sources/`) | The engine: OpenSubtitles hash, search and download. A Swift package; [Cargo](https://github.com/michellzappa/cargo) uses it too. `swift build && swift test` |
| `Subtitles/SubtitleQueue` | Dropped videos in, one at a time, `.srt` files out |
| `Drop/DropView` | The drop window: drop zone, recent videos, setup status |
| `Settings/SettingsStore` | Preferences and the Keychain password; copies EasySubs settings once |
| `Settings/SubsSettings` | The HouseKit settings shell: General, Subtitles, OpenSubtitles, About |
| `App/SubsApp` | `NSStatusItem`, the drop on its window, and its menu: header, recent videos, then the house tail (Settings, Launch at Login, Quit) |

## Matching

Subs first computes the standard OpenSubtitles hash from the first and last
64 KiB of the video plus its size. This usually identifies the exact release
and its timing. When no hash match exists, it searches by file name and takes
the most-downloaded result.

## Limitations

- One video at a time. A large drop waits in the queue.
- `.srt` only, one language at a time.
- The OpenSubtitles free tier limits downloads per day.
