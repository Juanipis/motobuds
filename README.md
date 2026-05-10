# MotoBuds for Mac

Native macOS companion app for **Motorola Moto Buds** (XT2443-1 "guitar" and
related models). Switches ANC modes, reads battery, monitors in-ear / in-case
state, and runs find-buds — all the things the official Android app does, on
your Mac.

> Built because Motorola never shipped an iOS or macOS app. If you went from
> Android to iPhone and your buds feel half-functional, this is for you.

<p align="center">
  <img src="docs/screenshot.png" width="640" alt="MotoBuds main window">
</p>

## Features

- **ANC modes** — Off, Transparency, ANC (high), Adaptive (light ANC). Sent
  via the same wire format as the bud's own touch button.
- **Battery** — left, right, case, all live with notifications.
- **In-ear / in-case detection** — visible in the UI in real time.
- **Find buds** — chime left or right.
- **Dual connection toggle** — let the buds keep two hosts at once.
- **Hi-res mode, Game mode, Volume Boost toggles** — all reading and writing.
- **Menu-bar quick controls** — battery + ANC selector without opening the window.

## Install

### Homebrew (recommended)

```bash
brew tap juanipis/tap
brew install --cask motobuds
```

### Manual

Download the latest `MotoBuds-x.y.z.zip` from the
[Releases](https://github.com/Juanipis/motobuds/releases) page, unzip, drag
`MotoBuds.app` into `/Applications`. First launch will ask for Bluetooth
permission — accept and you're done.

## Requirements

- macOS 14+ (Sonoma).
- Apple Silicon or Intel.
- A pair of Moto Buds **already paired** to your Mac via the standard
  Bluetooth pairing flow (Settings → Bluetooth → Pair).

## How it works

The buds expose three transports over their `moto buds` Bluetooth Classic
connection:

1. Audio (A2DP / HFP) — handled by macOS itself.
2. **RFCOMM SPP `fc9d9fe0-…` channel 16** — the same vendor SPP path the
   official Moto Buds Android app uses. MotoBuds opens this channel and
   speaks the BES (Bestechnic) toggle-config protocol over it.
3. OTA channels (`BESOTA`, `TOTA`) — left strictly alone.

Wire format and full opcode table are in
[`docs/protocol.md`](docs/protocol.md). Reverse-engineered from the
official APK; cross-references are in `Tools/DiscoverBuds`.

## Development

```bash
git clone https://github.com/Juanipis/motobuds.git
cd motobuds

swift test                            # unit tests
bash Bundle/build-app.sh debug        # assemble MotoBuds.app
bash Bundle/install.sh debug          # copy to /Applications + launch

# Watch the live log
tail -f ~/Library/Logs/MotoBudsMac.log
```

Run with the real RFCOMM transport:

```bash
MOTOBUDS_REAL=1 open -a /Applications/MotoBuds.app
```

Without `MOTOBUDS_REAL` the app runs against a mock transport with
simulated state — useful for UI work without hardware.

## Layout

```
.
├── Sources/MotoBudsApp/        # the SwiftUI app
│   ├── App/                    # @main + ContentView
│   ├── BudsCore/               # transport, protocol, manager
│   ├── Features/               # ANC, battery, find buds, … views
│   └── UI/                     # design system, menubar, hero
├── Tools/DiscoverBuds/         # SPM CLI for SDP/GATT discovery + SPP probe
├── Tests/MotoBudsAppTests/     # wire-format unit tests
├── Bundle/                     # AppInfo.plist, build/package/install scripts, icon
├── scripts/                    # bump-cask, update-appcast (release-time)
├── .github/workflows/          # CI + semantic-release
└── docs/protocol.md            # reverse-engineered wire spec
```

## Releases

Releases are driven by [semantic-release](https://semantic-release.gitbook.io/):

- Push to `main` with a [conventional commit](https://www.conventionalcommits.org/)
  message (`feat:`, `fix:`, …).
- CI builds the `.app`, zips it, computes a SHA-256, attaches both to a
  GitHub release, updates `CHANGELOG.md`, bumps the
  [Homebrew cask](https://github.com/Juanipis/homebrew-tap), and appends a
  Sparkle appcast entry so installed apps auto-update.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full commit-message
convention.

## Status

| Feature | Status |
|---|---|
| ANC modes (off/transparency/ANC/adaptive) | ✅ verified audibly |
| Battery (L/R/case) live | ✅ |
| In-ear and in-case detection | ✅ |
| Find buds | ✅ |
| Dual connection toggle | ✅ |
| Hi-res, game mode, volume boost | ✅ |
| Bass enhancement | ⚠️ silent on this firmware |
| Custom EQ | ❌ not supported by the `guitar` firmware |
| OTA firmware updates | ❌ won't ship — risky without docs |

## Credits

Inspired by the Android Moto Buds app v01.0.129.12 — wire format extracted
from its decompilation. Not affiliated with Motorola Mobility LLC.
"Moto Buds" and "Motorola" are trademarks of their respective owners.

## License

[MIT](LICENSE) © 2026 Juan Pablo Díaz Correa.
