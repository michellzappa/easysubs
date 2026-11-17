# Working on Subs

The repo is `easysubs`; the app is Subs. Drop a video on the menu bar icon
and Subs fetches its subtitle from OpenSubtitles. Swift 6, macOS 14, bundle
id `app.subs.Subs`. The subtitle engine is `EasySubsKit`, a Swift package
at the repo root (`Package.swift`, `Sources/`, `Tests/`).

## Build

XcodeGen owns the project. Edit `project.yml`, then run `xcodegen generate`.
`Subs.xcodeproj` is not in git. Never hand-edit it.

- `./scripts/build-app.sh` regenerates the project and the icon, builds
  Release, signs with the stable Apple Development identity and installs to
  `/Applications/Subs.app`. `--debug` builds Debug. This is for mz's Mac.
- The green gate is the CI build (`.github/workflows/build.yml`):

```bash
xcodegen generate && xcodebuild build -project Subs.xcodeproj -scheme Subs -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet
```

Run it on mz-mini with `remote-build '<command>'` from inside the clone. Do
not build Swift on the laptop.

CI also runs `swift test` for EasySubsKit.

## Shared package

HouseKit (`michellzappa/housekit`) supplies the menu bar plate, the app icon,
the status menu tail, the settings window, launch at login and the changelog
parser. `project.yml` pins a HouseKit release tag by URL (`exactVersion`), so
CI, mz-mini and the laptop build the same code.

- To change HouseKit: merge in its repo, tag a new release, then move the pin
  here on purpose. Never go back to `path: ../housekit`.
- `scripts/build-app.sh` builds `housekit-icon` from the resolved package
  checkout in `build/DerivedData`. Set `HOUSEKIT_PATH` to try a local
  HouseKit clone.
- `EasySubsKit` is this repo's own package (`path: .`). Cargo depends on
  it as a sibling checkout (`../easysubs`), so a change to its public API can
  break Cargo. Build Cargo too when you change it.

## Release

`.github/workflows/release.yml` runs on a `v*` tag. The tag must match
`CFBundleShortVersionString` in `Subs/Resources/Info.plist`. The workflow archives a
universal app, signs it with Developer ID, notarizes, staples and publishes a
zip plus `SHA256SUMS` to GitHub Releases.

- Add a `CHANGELOG.md` entry `## X.Y.Z - YYYY-MM-DD` before you tag. The app
  bundles the file for HouseKit's About pane.
- The workflow needs six secrets: `APPLE_TEAM_ID`,
  `APPLE_DEVELOPER_CERTIFICATE_P12_BASE64`, `APPLE_DEVELOPER_CERTIFICATE_PASSWORD`,
  `APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID`, `APPLE_API_PRIVATE_KEY_BASE64`.

## Traps

- This repo has no Actions secrets, so a tag push fails at signing. Add the
  secrets before the first tag.
- Keychain ties its access grant to the code signature. Sign local builds
  with the stable Apple Development identity (`build-app.sh` does this), or
  the OpenSubtitles password prompt comes back on every rebuild.
- An `LSUIElement` app can get the generic icon from
  `applicationIconImage`. About reads the `AboutAppIcon` asset, which
  `build-app.sh` renders with `housekit-icon`.
- Subs copies EasySubs settings and the Keychain password on first launch.
  Do not remove that migration while old installs exist.

## Writing

Docs, comments and commit messages use Simplified Technical English: active
voice, short sentences, one word for one thing. No em dashes in UI copy.
