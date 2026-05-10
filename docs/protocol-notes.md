# Protocol notes — Moto Buds (PG38C05875)

Trabajo vivo. Se va llenando a medida que descubrimos.

## Identidad del dispositivo

- **Nombre Bluetooth**: `moto buds`
- **MAC**: `a4-05-6e-d9-c9-14`
- **Class of Device**: `0x240404` → Major=Audio (0x04), Minor=Wearable Headset (0x01), Service=Audio + Rendering
- **Estado al captar el dump**: emparejado y conectado a la Mac.

## Servicios SDP (Bluetooth Classic)

Servicios Bluetooth estándar (audio):
| UUID | Nombre | Transporte |
|---|---|---|
| `0x1108` HSP | Headset (HF) | RFCOMM ch 1 |
| `0x111e` HFP | Hands-Free | RFCOMM ch 1 |
| `0x1203` GenericAudio | — | RFCOMM ch 1 |
| `0x110b` AudioSink | A2DP sink | L2CAP PSM 0x19 |
| `0x110e` AVRCP Controller | — | L2CAP PSM 0x17 |
| `0x110c` AVRCP Target | — | L2CAP PSM 0x17 |
| `0x110f` Advanced Audio | A2DP source | L2CAP PSM 0x17 |
| `0x1200` PnP / Device ID | — | L2CAP PSM 0x1 |

**Servicios vendor (donde está el protocolo de control):**

| Nombre SDP | RFCOMM ch | UUID custom | Pista |
|---|---|---|---|
| `SPP_MOBILe` | **20** | `182b0100-4899-11ee-be56-0242ac120002` | App↔buds principal (probable) |
| `SPP_MOBILE` | **16** | `fc9d9fe0-4899-11ee-be56-0242ac120002` | Segundo canal de app (¿L vs R? ¿events?) |
| `RFCOMM COM` | **17** | `df21fe2c-2515-4fdb-8886-f12c4d67927c` | Tercer canal — propósito por confirmar |
| `TOTA` | 12 | `0x1101` (SPP) | **OTA — NO TOCAR** |
| `BESOTA` | 13 | `66666666-6666-6666-6666-666666666666` | **BES OTA — NO TOCAR** |
| (unnamed) | 29 | `99999999-...-99999999` | Reservado / interno |

### Inferencias clave

1. **Chipset = Bestechnic (BES)**. El servicio `BESOTA` y el patrón de UUIDs `0x6666…` / `0x9999…` son firmas inequívocas de los SoC BES23xx/BES25xx/BES27xx (mismo silicio detrás de muchos TWS chinos OEM, e.g. HiFi Walker, Tronsmart, Edifier, Soundcore baratos).
2. **Transport del protocolo de control = RFCOMM SPP** (no GATT). Las UUIDs custom de `SPP_MOBIL*` son los endpoints donde la app oficial habla.
3. La app oficial Moto Buds probablemente abre **uno** de los canales SPP y multiplexa todas las features ahí — o usa dos (uno comandos, otro notifs). El sniffer pasivo lo aclarará.

## Pendiente (siguiente paso)

- [ ] Sniffer RFCOMM pasivo: abrir ch 16, 17 y 20 sucesivamente, leer todos los bytes que llegan durante 15s, ver si hay heartbeats o anuncios espontáneos.
- [ ] Probar también con buds tocados (long-press, cambio de modo manual) para ver si emiten eventos por el canal.
- [ ] Analizar APK Moto Buds para mapear opcodes a acciones.
- [ ] Buscar referencias públicas de protocolo BES SPP (suele venir con framing `0x05 0xea` ó `0xbe 0xef` y CRC al final).
