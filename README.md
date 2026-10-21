# Clipboard Cleaner

A native macOS menu-bar app that automatically cleans copied links. Removes
tracking parameters, unwraps supported redirects, and shortens selected product
links. Everything runs locally.

**[Download v1.0.3](https://github.com/thetoadsage/clipboard-cleaner/releases/tag/v1.0.3)** · macOS 12 or later

## Install

1. Download the DMG from the release page.
2. Open it and drag **Clipboard Cleaner** into **Applications**.
3. Launch the app and look for the clipboard icon in the menu bar.

Builds are ad-hoc signed and not notarized.

## What it cleans

- Tracking parameters such as `utm_*`, `fbclid`, `gclid`, and newer click IDs.
- Embedded destinations in supported Google, Facebook, DuckDuckGo, Bing,
  LinkedIn, Instagram, Threads, shopping, and Reddit email redirects.
- Product links from Amazon, AliExpress, Best Buy, and Walmart, plus MakerWorld
  model links. These rewrites can remove query options and fragments.
- YouTube share, radio, and favorites context, while keeping timestamps and
  ordinary playlists.

Site-specific exceptions protect reviewed login and redirect parameters.
Unknown parameters are kept outside the product/model rewrites above.
Shorteners such as `bit.ly` and `t.co` stay unchanged because resolving them
would require a network request.

Automatic cleaning supports single copied URLs, including matching URL-only
HTML links. Other rich content, images, files, and multi-item copies are skipped.

## Use

Copy a link normally; the app cleans it on the clipboard. From the menu:

- **Clean Current Clipboard** runs once, even when monitoring is off. A changed
  link is replaced with plain text.
- **Settings** controls monitoring, optional History, statistics visibility,
  and **Launch at Login** on macOS 13 or later.
- **History** shows recent cleaned links when **Keep History** is enabled.

## Privacy

- No network requests or clipboard-content logging.
- Optional History is off by default, stays in memory, and clears on quit.
- Only preferences and aggregate cleaning counters are saved to disk.
- Built app bundles use App Sandbox without network entitlements.

## Development

Requires a Swift 6 toolchain on macOS.

| Task | Command |
| --- | --- |
| Run | `swift run` |
| Swift tests | `./test.sh` |
| Updater tests | `python3 -m unittest discover -s Tests/UpdaterTests` |
| Build app | `./scripts/build_app.sh` |
| Package DMG | `./scripts/package_dmg.sh` |
| Package ZIP and checksum | `./scripts/package_release.sh` |

The app is built at `build/Clipboard Cleaner.app`; packages go to `dist/`.
Versions come from numeric `v` tags, or `CLIPBOARD_CLEANER_VERSION` when set.

Core cleaning logic lives in `Sources/ClipboardCleanerCore`; the menu and
clipboard handling live in `Sources/ClipboardCleaner`. CI runs tests, release
builds, bundle verification, and packaging checks.

To refresh the bundled tracking catalog:

```bash
python3 scripts/update_tracking_rules.py
```

This manual maintainer step downloads pinned ClearURLs data and retains the
local reviewed uAssets snapshot in `scripts/uassets-reviewed-rules.json`.
The app never runs the updater. Rule changes need removal and preservation
regression tests.

## Credits and license

App source: [MIT](LICENSE). Rule data comes from
[ClearURLs](https://github.com/ClearURLs/Rules) and
[uAssets](https://github.com/uBlockOrigin/uAssets), with separate LGPL-3.0 and
GPL-3.0 terms. [Link Cleaner](https://github.com/corbindavenport/link-cleaner)
was a design reference; no code was copied from it.
See [third-party attribution](THIRD_PARTY_LICENSES/README.md) for details.

[Support development on Ko-fi](https://ko-fi.com/kingtoad).
