# Contributing to MotoBuds

Thanks for taking the time! Quick rules:

## Commit messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/) so that
[semantic-release](https://github.com/semantic-release/semantic-release) decides the
next version number and writes the changelog automatically.

Format: `type(scope): subject`

| Type | Effect on the next release |
|------|----------------------------|
| `feat:` | minor bump (new feature) |
| `fix:`  | patch bump (bug fix) |
| `perf:` / `refactor:` | patch bump |
| `docs:` / `style:` / `chore:` / `test:` / `ci:` | no release |
| `feat!:` (or `BREAKING CHANGE:` in the body) | major bump |

Example: `feat(anc): support adaptive hearing toggle`

## Development loop

```bash
swift test                           # unit tests
bash Bundle/build-app.sh debug       # assemble MotoBuds.app
bash Bundle/install.sh debug         # copy to /Applications + open
tail -f ~/Library/Logs/MotoBudsMac.log
```

Run with the real RFCOMM transport against your buds:

```bash
MOTOBUDS_REAL=1 open -a /Applications/MotoBuds.app
```

Without `MOTOBUDS_REAL` the app uses a mock transport with simulated state — handy
for UI work without hardware.

## Reverse-engineering tools

The `Tools/DiscoverBuds` package ships a CLI/.app for poking the buds: SDP
enumeration, RFCOMM channel sniff, and a scriptable SPP probe. See
`docs/protocol.md` for the wire format and `Tools/DiscoverBuds/build-app.sh`
for usage.

```bash
# enumerate paired devices
Tools/DiscoverBuds/build-app.sh discover

# send a sequence of opcodes and observe responses
Tools/DiscoverBuds/build-app.sh probe <MAC> 16 anc-cycle
```

The `apk/` directory is **gitignored** — it's a local-only scratch space
for proprietary code we don't redistribute.

## Reporting issues

Include:

- macOS version (`sw_vers`)
- Buds model (Settings → Bluetooth — should say `moto buds`)
- Output of `Tools/DiscoverBuds/build-app.sh discover`
- The last ~50 lines of `~/Library/Logs/MotoBudsMac.log`
