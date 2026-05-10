# Moto Buds protocol — extracted from APK 01.0.129.12

Source of truth: official `Moto Buds` Android app (`com.motorola.motobuds` v01.0.129.12).
Decompiled with `jadx` 1.5.5. Cross-references in `apk/jadx-out/sources/`:

- `o4/C1435c.java` — base PDU class (`f17542g` HashMap has the canonical opcode→name table)
- `p4/d.java` — `BudsProxy`: orchestrates send/receive, defines `q()` and `t()`
- `p4/f.java` — `LeConnection`: GATT connection mgmt, characteristic discovery, write
- `q4/C1537a.java` — `PduParser`: byte helpers (`h`, `p`, `c`, `n`, `b`), feature→opcode mapper `e()`
- `T0/RunnableC1833w.java` case 4 — **SPP wire encoder**
- `v1/RunnableC1959d.java` case 5 — **GATT wire encoder** (this is what we use)
- `assets/buds_features.json` — model catalog (model `guitar` = XT2443-1 = the user's "Moto Buds")

## Transport: GATT (Bluetooth Low Energy)

Even though the buds expose RFCOMM SPP service records with the same UUIDs, the
official Android app talks **GATT**. The SPP path is only used by some models
(e.g. when `n()` returns true in `BudsProxy`) — for our model `guitar`, GATT is
the path.

### Service & characteristics

The app probes both UUID generations and uses whichever one the firmware exposes:

| Generation | Service UUID | Notes |
|---|---|---|
| Old (`00009fe0`) | `00009fe0-4899-11ee-be56-0242ac120002` | Legacy firmwares |
| New (`fc9d9fe0`) | `fc9d9fe0-4899-11ee-be56-0242ac120002` | Current firmwares |

**Our buds expose the NEW UUID** (confirmed in SDP dump — `SPP_MOBILE` ch 16 has
`fc9d9fe0-...`), so we target the new family. Each service has 4 characteristics
plus a separate OTA service:

| Field | UUID | Role (inferred) |
|---|---|---|
| `f17703e` | `fc9d9ff0-...` | **command write** (main commands) |
| `f17704f` | `fc9d9ff1-...` | **notify** (responses & events for main) |
| `f17705g` | `fc9d9ff2-...` | command write (large transfers — logs, etc.) |
| `f17706h` | `fc9d9ff3-...` | notify (large transfers) |
| `f17707i` | `77777777-7777-7777-7777-777777777777` (under service `66666666-...`) | **OTA — DO NOT TOUCH** |

CCCDs (`0x2902`) on the notify characteristics are written `[0x01, 0x00]` to
enable notifications.

The app *requires* both `f17703e` and `f17705g` to be present before allowing
any command (`p4/d.java:531`). We mirror that gate.

## Wire format (GATT)

From `RunnableC1959d.run()` case 5 (the GATT encoder):

```
offset  size  field        encoding         meaning
------  ----  -----------  ---------------  ----------------------------
   0     2    opcode       big-endian       0..0x7FF, see Opcode table
   2     1    type         u8               0x80 = command-ack (we always use this)
   3     1    result       u8               0 for outgoing commands
   4     2    inner_length little-endian    payload length only
   6     2    seq          little-endian    monotonic counter, per-opcode-class
   8    N     payload      raw              opcode-specific
```

**Header is exactly 8 bytes.** No CRC, no HEAD/TAIL marker, no outer length —
GATT ATT writes are already framed at the L2CAP layer.

### Type byte (`f17544b`)

| Value | Meaning |
|---|---|
| `0x00` | command no-ack |
| `0x20` | response no-ack |
| `0x40` | notification no-ack |
| `0x80` | **command ack** ← what we use for outgoing commands |
| `0xA0` | response ack (what the buds send back) |
| `0xC0` | notification ack |

(From the toString() switch in `o4/C1435c.java`.)

### Sequence counters

`p4/d.java:t()` uses three different counters depending on opcode:

- `f17711m` → opcodes 1792, 1793 (log)
- `f17717s` → opcodes 1282, 1283 (check-point)
- `f17710l` → everything else (general)

Resets:
- 1792 (`get log collect data status`) resets `f17711m` to 0.
- 1282 (`get check point data status`) resets `f17717s` to 0.

For our v1 we only need the general counter — we don't touch logs.

### SPP wire format (informational, not used)

When the SPP path is taken (other models), the same inner PDU is wrapped:

```
"HEAD" (4) | outer_len (2 LE) | inner PDU (8+payload) | CRC32 (4 LE) | "TAIL" (4)
```

`outer_len = 8 + payload.length`. CRC32 is over `[outer_len .. payload]` (i.e.
everything between HEAD and the CRC itself), little-endian.

## Opcode table (verbatim from `o4/C1435c.java`)

| Opcode | Hex | Name |
|---|---|---|
| 0 | 0x000 | get profile version |
| 1 | 0x001 | get support features |
| 2 | 0x002 | get support configurations |
| 3 | 0x003 | get device name |
| 4 | 0x004 | get hardware info |
| 5 | 0x005 | **get battery level** |
| 6 | 0x006 | get primary earbud |
| 7 | 0x007 | set device name |
| 8 | 0x008 | primary earbud changed (notif) |
| 9 | 0x009 | **battery level changed** (notif) |
| 10 | 0x00A | get earbuds color |
| 11 | 0x00B | list support info and configs |
| 12 | 0x00C | get channel id |
| 13 | 0x00D | set support configurations |
| 14 | 0x00E | support configurations changed (notif) |
| 15 | 0x00F | read random nonce |
| 16 | 0x010 | read account key |
| 256 | 0x100 | get toggle configs |
| 257 | 0x101 | get toggle config |
| 258 | 0x102 | set toggle config |
| 259 | 0x103 | get demo state |
| 260 | 0x104 | set demo state |
| 261 | 0x105 | toggle config status changed (notif) |
| 262 | 0x106 | demo state changed (notif) |
| **512** | 0x200 | **get current ANC mode** |
| **513** | 0x201 | **set current ANC mode** |
| 514 | 0x202 | get adaptation status |
| 515 | 0x203 | set adaptation status |
| 516 | 0x204 | ANC mode changed (notif) |
| 517 | 0x205 | adaptation status changed (notif) |
| 518 | 0x206 | set ear canal state |
| 519 | 0x207 | ear canal status indication (notif) |
| 520 | 0x208 | get danger detection state |
| 521 | 0x209 | set danger detection state |
| 522 | 0x20A | danger detection state changed (notif) |
| 768 | 0x300 | get EQ state |
| 769 | 0x301 | get available EQ sets |
| 770 | 0x302 | get EQ set |
| 771 | 0x303 | set EQ set |
| 772 | 0x304 | get user set number of bands |
| 773 | 0x305 | get user set config |
| 774 | 0x306 | set user set config |
| 775 | 0x307 | EQ state changed (notif) |
| 776 | 0x308 | EQ set changed (notif) |
| 777 | 0x309 | EQ user bands changed (notif) |
| 778 | 0x30A | get spatial audio state |
| 779 | 0x30B | set spatial audio state |
| 780 | 0x30C | **get hi-res mode** |
| 781 | 0x30D | **set hi-res mode** |
| 782 | 0x30E | **get game mode** |
| 783 | 0x30F | **set game mode** |
| 784 | 0x310 | spatial audio state changed (notif) |
| 785 | 0x311 | hi-res mode state changed (notif) |
| 786 | 0x312 | game mode state changed (notif) |
| 787 | 0x313 | **get volume boost state** |
| 788 | 0x314 | **set volume boost state** |
| 789 | 0x315 | volume boost state changed (notif) |
| 790 | 0x316 | get auto volume state |
| 791 | 0x317 | set auto volume state |
| 792 | 0x318 | get case recording state |
| 793 | 0x319 | set case recording state |
| 794 | 0x31A | auto volume state changed (notif) |
| 795 | 0x31B | case recording state changed (notif) |
| 796 | 0x31C | **get bass enhancement state** |
| 797 | 0x31D | **set bass enhancement state** |
| 798 | 0x31E | bass enhancement state changed (notif) |
| 1024 | 0x400 | set fit state |
| 1025 | 0x401 | fit status changed (notif) |
| 1026 | 0x402 | **get in-ear detection state** |
| 1027 | 0x403 | **set in-ear detection state** |
| 1028 | 0x404 | in-ear status changed (notif) |
| **1029** | 0x405 | **find my device** |
| 1030 | 0x406 | **get dual connection state** |
| 1031 | 0x407 | **set dual connection state** |
| 1032 | 0x408 | get dual connection device |
| 1033 | 0x409 | dual connection device changed (notif) |
| 1034 | 0x40A | get LE audio state |
| 1035 | 0x40B | set LE audio state |
| 1036 | 0x40C | in-case status indication (notif) |
| 1037 | 0x40D | in-ear detection state notification |
| 1038 | 0x40E | find my device state notification |
| 1039 | 0x40F | dual connection state changed notification |
| 1040 | 0x410 | LE audio state changed notification |
| 1280 | 0x500 | set current time |
| 1281 | 0x501 | check point data changed (notif) |
| 1282 | 0x502 | get check point data status |
| 1283 | 0x503 | get check point data |
| 1536 | 0x600 | get FMD config values |
| 1537 | 0x601 | set FMD config values |
| 1792 | 0x700 | get log collect data status |
| 1793 | 0x701 | get log collect data |
| 1794 | 0x702 | get log data type |
| 2560 | 0xA00 | audio sharing control |
| 2561 | 0xA01 | get audio sharing state |
| 2562 | 0xA02 | audio sharing notification |

**Bold = features supported by our `guitar` model (XT2443-1).**

## Feature catalog for our model

From `assets/buds_features.json`, model `guitar` (XT2443-1):

```
feature_list = [104, 116, 117, 121, 109, 110, 112, 113, 114, 120, 105]
```

| ID | Feature | Implementable now? |
|---|---|---|
| 104 | active_noise_cancellation | ✅ opcode 513 |
| 105 | adaptive_hearing | ✅ opcode 515 (set) / 514 (get) |
| 109 | hi_res | ✅ opcode 781 |
| 110 | game_mode | ✅ opcode 783 |
| 112 | bass_enhancement | ✅ opcode 797 |
| 113 | volume_boost | ✅ opcode 788 |
| 114 | crystal_talk | ⚠️ no obvious opcode — may go through 258 (set toggle config) |
| 116 | in_ear_detection | ✅ opcode 1027 |
| 117 | fit_test | ✅ opcode 1024 (set fit state) |
| 120 | dual_connection | ✅ opcode 1031 |
| 121 | ring_buds (find buds) | ✅ opcode 1029 |

**NOT supported by `guitar`** (so we hide in UI): equalizer (108), spatial audio
(106), head tracking (107), auto volume (111), danger detection (118), audio
sharing (119).

## ANC: the right way (verified empirically)

The legacy `setANCMode` (opcode `0x201`) **always returns `result=2` (rejected)**
on this firmware regardless of payload. Don't use it.

The official Android app uses **`setToggleConfig` (opcode `0x102`)** with a
3-byte payload `[feature_id, category, sub]` for ANC. Verified live:

| Mode | Payload | Notes |
|---|---|---|
| Off | `01 00 00` | feature 1 (ANC), category 0 |
| ANC | `01 01 02` | category 1, sub = strength (1/2/3) |
| Transparency | `01 02 00` | category 2 |
| Adaptive | `01 01 01` + `0x203 [01]` | ANC at low strength + setAdaptationStatus on |

Response: `op=0x102 type=0x20 res=0 payload=[]` (success ack), followed by
notification `op=0x105 (toggle_config_changed) payload=[01, category, sub]`
confirming the new state.

The legacy reads (`op=0x200 get_anc_mode`) still respond with `[mode_byte, flag]`
but their `mode_byte` doesn't reflect changes made via `0x102`. To track the
real state, listen for `0x105` notifications and parse `op=0x100`
(get_toggle_configs) on connect.

## Find buds (opcode 1029)

`q(1029, ...)` — payload likely `[side, on/off]` where side: 0=left, 1=right
(or 2=both). To be confirmed at smoke test.

## Dual connection (opcode 1031)

From `p4/d.java:566`:
```java
q(setOpcode, new byte[]{
    (byte) ((j() == null || j().a(13) == null) ? 1 : j().a(13).a(0)),
    (byte) i8
})
```
First byte is the current "config sub-feature 13" value (a sub-id), second byte
is the desired state (0/1). For us we'll send `[1, on]` — fallback when no
config cached.

## What we still need to learn (smoke test in app, capture in PacketLogger)

1. Exact payload encoding for find buds (1029).
2. Battery payload structure (response of opcode 5).
3. Whether write characteristic for ANC is `9ff0` or `9ff2`. We'll start with
   `9ff0`; if no ack on `9ff1`, fall back.
4. Adaptive vs ANC byte order — verify with audible test.
