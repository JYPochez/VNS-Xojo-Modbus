# Hitachi ATW-MBS-02 / Yutaki — Modbus register reference

Register reference for the Hitachi airH2O / Yutaki heat pump through its **ATW-MBS-02** Modbus gateway, as used by the example app of this repository. Extracted 2026-09-20 from the Hitachi manual **PMML0419 rev.3 - 03/2024** ([download](https://github.com/alepee/hass-hitachi_yutaki/blob/main/docs/gateway/datasheets/ATW-MBS-02_line_up_2016.pdf)) and cross-checked against a live unit.

> Extracted from **§5.3 "DATA AVAILABLE FOR LINE-UP YUTAKI 2016 SERIES"** — the table that applies to this unit. The manual also contains §5.2 for pre-2016 Yutaki, whose addresses **differ**; using it returns plausible-looking wrong values, not an error. See [Which table](#which-table) below.

The manual itself is not stored in this repository; see the References section of the [README](../README.md).

## Connection

| | |
|---|---|
| Host | `192.168.2.162` on the author's LAN — yours will differ |
| Port | `502` (Modbus TCP) |
| Function codes | **FC3** and FC4 both work and return the *same* table |
| FC1 / FC2 | not supported — return `exception 1 (illegal function)` |
| Unit / slave ID | **ignored** — IDs 0–5 all answer identically |
| Unmapped address | returns `0xFFFF`, *never* an exception |
| Writing | **FC6** (write single register) — single-register writes, no block writes |
| Hardware ID | FC4 addresses 0–2, read as one identifier |

Because unmapped reads return `0xFFFF` instead of failing, a wrong address is silent. Three values mean "no reading" rather than a measurement:

| Value | Meaning |
|---|---|
| `0xFFFF` | register not implemented, or sensor error |
| `-127` | sensor not fitted (seen here on the swimming-pool probe, addr 1083) |
| `-67` | module unavailable (seen here on addrs 1202–1203) |

The `-127` / `-67` conventions are not in the manual; they come from the `hass-hitachi_yutaki` integration (see [Cross-check](#cross-check)) and match what this unit returns.

## ⚠ Address = Register − 1

The manual prints a **Register** column and an **Address** column. The Modbus address on the wire is the *Address* column, i.e. **one less** than the Register column.

```
manual: Register 1081  Status DHW Temperature
wire:   address  1080   <-- use this
```

Both are given in the tables below; the **bold Addr column is what you send**.

## Scaling — not uniform

This is the other easy way to get wrong numbers:

| Range in manual | Meaning | Example |
|---|---|---|
| `-80~100 °C (*1)` | **whole degrees**, signed 16-bit two's complement | `44` = 44 °C, `0xFF81` = −127 |
| `0~80 °C(*3)` | **whole degrees**, unsigned | `45` = 45 °C |
| `0~1000 (0,0~100,0 °C)` | **×10** | `235` = 23.5 °C |
| `50~350 (5,0~35,0 °C)` | **×10** | `215` = 21.5 °C |
| `0~30 (0,0~3,0 m³/h)` | **×10** | `12` = 1.2 m³/h |

So water/DHW/ambient temperatures are whole degrees, while *thermostat* room and setting temperatures are tenths. Mixing these up gives a plausible 10× error.

## Which table

§5.3 (2016 line-up) is confirmed for this unit, not assumed — at §5.3 addresses the whole block decodes coherently:

```
  1076 = 1   DHWT Run/Stop        -> Run
  1077 = 45  DHWT Setting Temp    -> 45 °C
  1080 = 44  DHW Temperature      -> 44 °C   (just under setpoint)
  1081 = 0   Swimming Pool Run    -> Stop
  1083 = 0xFF81  Swimming Pool Temp   -> -127 = no probe fitted
  1085 = 70  Anti-Legionella Temp -> 70 °C
```

Under §5.2's map those same bytes land on unrelated fields.

## This installation

Read from the unit, not assumed:

- **Unit model** (addr 1218) = `1` → **YUTAKI S COMBI**
- **Central mode** (addr 1088) = `3` → Full
- **Fitted functions** (addr 1089 bitfield) = 0x00D1 = Circuit 1 Heating, DHWT, Room thermostat Circuit 1, Room thermostat Circuit 2
- Circuit 2 present in the register map but **not running** (addr 1064 = 0); all circuit-2 values read 0.
- No swimming pool probe (addr 1083 = -127).

## Registers

The **Seen** column is a snapshot taken 2026-09-20 — it shows what a plausible value looks like and which registers are actually populated on this installation. `—` means the register read `0xFFFF` (not implemented here).

### Control block (read/write) — 1000–1033

Writing here commands the unit (FC6, one register per request). The example app writes these only through its guarded write path, in *control* mode.

| Addr | Reg | R/W | Description | Values / range | Seen |
|-----:|----:|:---:|-------------|----------------|------|
| **1000** | 1001 | R/W | Control Unit Run/Stop | 0: Stop<br>1: Run | 1 → Run |
| **1001** | 1002 | R/W | Control Unit Mode | 0: Cool (*2)<br>1: Heat<br>2: Auto | 1 → Heat |
| **1002** | 1003 | R/W | Control Circuit 1 Run/Stop | 0: Stop<br>1: Run | 0 → Stop |
| **1003** | 1004 | R/W | Control Heat. OTC Circuit 1 | 0: No<br>1: Points<br>2: Gradient<br>3: Fix | 2 → Gradient |
| **1004** | 1005 | R/W | Control Cool. OTC Circuit 1 (*2) | 0: No<br>1: Points<br>2: Fix | 0 → No |
| **1005** | 1006 | R/W | Control Circuit 1: Water heating Fix Setting Temp | 0~80 °C(*3) | 40 °C |
| **1006** | 1007 | R/W | Control Circuit 1: Water cooling Fix Setting Temp (*2) | 0~80 °C(*3) | 19 °C |
| **1007** | 1008 | R/W | Control Circuit 1: Eco mode | 0: ECO<br>1: Comfort | 1 → Comfort |
| **1008** | 1009 | R/W | Control Circuit 1: Heat ECO Offset Temperature | 1~10 | 3 |
| **1009** | 1010 | R/W | Control Circuit 1: Cool ECO Offset Temperature (*2) | 1~10 | 3 |
| **1010** | 1011 | R/W | Control Circuit 1: Thermostat Available (*7) | 0: Not Available<br>1: Available | 0 → Not Available |
| **1011** | 1012 | R/W | Control Circuit 1: Thermostat Setting Temperature | 50~350 (5,0~35,0 °C) | 0 → 0.0 °C |
| **1012** | 1013 | R/W | Control Circuit 1: Thermostat Room Temperature (*8) | 0~1000 (0,0~100,0 °C) | 235 → 23.5 °C |
| **1013** | 1014 | R/W | Control Circuit 2 Run/Stop | 0: Stop<br>1: Run | 0 → Stop |
| **1014** | 1015 | R/W | Control Heat. OTC Circuit 2 | 0: No<br>1: Points<br>2: Gradient<br>3: Fix | 0 → No |
| **1015** | 1016 | R/W | Control Cool. OTC Circuit 2 (*2) | 0: No<br>1: Points<br>2: Fix | 0 → No |
| **1016** | 1017 | R/W | Control Circuit 2: Water heating Fix Setting Temp | 0~80 °C(*3) | 40 °C |
| **1017** | 1018 | R/W | Control Circuit 2: Water cooling Fix Setting Temp (*2) | 0~80 °C(*3) | 19 °C |
| **1018** | 1019 | R/W | Control Circuit 2: Eco mode | 0: ECO<br>1: Comfort | 1 → Comfort |
| **1019** | 1020 | R/W | Control Circuit 2: Heat ECO Offset Temperature | 1~10 | 3 |
| **1020** | 1021 | R/W | Control Circuit 2: Cool ECO Offset Temperature (*2) | 1~10 | 3 |
| **1021** | 1022 | R/W | Control Circuit 2: Thermostat Available (*7) | 0: Not Available<br>1: Available | 0 → Not Available |
| **1022** | 1023 | R/W | Control Circuit 2: Thermostat Setting Temperature | 50~350 (5,0~35,0 °C) | 0 → 0.0 °C |
| **1023** | 1024 | R | Control Circuit 2: Thermostat Room Temperature (*8) | 0~1000 (0,0~100,0 °C) | 0 → 0.0 °C |
| **1024** | 1025 | R/W | Control DHWT Run/Stop | 0: Stop<br>1: Run | 1 → Run |
| **1025** | 1026 | R/W | Control DHWT Setting Temperature | 0~80 °C(*3) | 45 °C |
| **1026** | 1027 | R/W | Control DHW Boost | 0: No request<br>1: Request | 0 → No request |
| **1027** | 1028 | R/W | Control DHW Demand Mode | 0: Standard<br>1: High demand | 0 → Standard |
| **1028** | 1029 | R/W | Control Swimming Pool Run/Stop | 0: Stop<br>1: Run | 0 → Stop |
| **1029** | 1030 | R/W | Control Swimming Pool Setting Temperature | 0~80 °C(*3) | 24 °C |
| **1030** | 1031 | R/W | Control Anti Legionella Run (*9) | 0: Stop<br>1: Run | 0 → Stop |
| **1031** | 1032 | R/W | Control Anti Legionella Setting Temperature | 0~80 °C(*3) | 70 °C |
| **1032** | 1033 | R/W | Control Block menu (*6) | 0: No<br>1: Block | 0 → No |
| **1033** | 1034 | R/W | Control BMS Alarm (*4) | 0: No Alarm<br>1: Alarm | 0 → No Alarm |

### Status block (read-only) — 1050–1098

Mirrors of the control block plus the live measurements. **This is what to poll.**

| Addr | Reg | R/W | Description | Values / range | Seen |
|-----:|----:|:---:|-------------|----------------|------|
| **1050** | 1051 | R | Status Unit Run/Stop | 0: Stop<br>1: Run | 1 → Run |
| **1051** | 1052 | R | Status Unit Mode | 0: Cool (*2)<br>1: Heat | 1 → Heat |
| **1052** | 1053 | R | Status Circuit 1 Run/Stop | 0: Stop<br>1: Run | 0 → Stop |
| **1053** | 1054 | R | Status Heat. OTC Circuit 1 | 0: No<br>1: Points<br>2: Gradient<br>3: Fix | 2 → Gradient |
| **1054** | 1055 | R | Status Cool. OTC Circuit 1 (*2) | 0: No<br>1: Points<br>2: Fix | 0 → No |
| **1055** | 1056 | R | Status Circuit 1: Water heating Fix Setting Temp | 0~80 °C(*3) | 40 °C |
| **1056** | 1057 | R | Status Circuit 1: Water cooling Fix Setting Temp (*2) | 0~80 °C(*3) | 19 °C |
| **1057** | 1058 | R | Status Circuit 1: Eco mode | 0: ECO<br>1: Comfort | 1 → Comfort |
| **1058** | 1059 | R | Status Circuit 1: Heat ECO Offset Temperature | 1~10 | 3 |
| **1059** | 1060 | R | Status Circuit 1: Cool ECO Offset Temperature (*2) | 1~10 | 3 |
| **1060** | 1061 | R | Status Circuit 1: Thermostat Setting Temperature | 50~350 (5,0~35,0 °C) | 0 → 0.0 °C |
| **1061** | 1062 | R | Status Circuit 1: Thermostat Room Temperature | 0~1000 (0,0~100,0 °C) | 235 → 23.5 °C |
| **1062** | 1063 | R | Status Circuit 1: Wireless Setting Temperature (*5) | 50~350 (5,0~35,0 °C) | 0 → 0.0 °C |
| **1063** | 1064 | R | Status Circuit 1: Wireless Room Temperature (*5) | 0~1000 (0,0~100,0 °C) | 0 → 0.0 °C |
| **1064** | 1065 | R | Status Circuit 2 Run/Stop | 0: Stop<br>1: Run | 0 → Stop |
| **1065** | 1066 | R | Status Heat. OTC Circuit 2 | 0: No<br>1: Points<br>2: Gradient<br>3: Fix | 0 → No |
| **1066** | 1067 | R | Status Cool. OTC Circuit 2 (*2) | 0: No<br>1: Points<br>2: Fix | 0 → No |
| **1067** | 1068 | R | Status Circuit 2: Water heating Fix Setting Temp | 0~80 °C(*3) | 40 °C |
| **1068** | 1069 | R | Status Circuit 2: Water cooling Fix Setting Temp (*2) | 0~80 °C(*3) | 19 °C |
| **1069** | 1070 | R | Status Circuit 2: Eco mode | 0: ECO<br>1: Comfort | 1 → Comfort |
| **1070** | 1071 | R | Status Circuit 2: Heat ECO Offset Temperature | 1~10 | 3 |
| **1071** | 1072 | R | Status Circuit 2: Cool ECO Offset Temperature (*2) | 1~10 | 3 |
| **1072** | 1073 | R | Status Circuit 2: Thermostat Setting Temperature | 50~350 (5,0~35,0 °C) | 0 → 0.0 °C |
| **1073** | 1074 | R | Status Circuit 2: Thermostat Room Temperature | 0~1000 (0,0~100,0 °C) | 0 → 0.0 °C |
| **1074** | 1075 | R | Status Circuit 2: Wireless Setting Temperature (*5) | 50~350 (5,0~35,0 °C) | 0 → 0.0 °C |
| **1075** | 1076 | R | Status Circuit 2: Wireless Room Temperature (*5) | 0~1000 (0,0~100,0 °C) | 0 → 0.0 °C |
| **1076** | 1077 | R | Status DHWT Run/Stop | 0: Stop<br>1: Run | 1 → Run |
| **1077** | 1078 | R | Status DHWT Setting Temperature | 0~80 °C(*3) | 45 °C |
| **1078** | 1079 | R | Control DHW Boost | 0: Disable<br>1: Enable | 0 → Disable |
| **1079** | 1080 | R | Status DHW Demand Mode | 0: Standard<br>1: High demand | 0 → Standard |
| **1080** | 1081 | R | Status DHW Temperature | -80~100 °C (*1) | 44 °C |
| **1081** | 1082 | R | Status Swimming Pool Run/Stop | 0: Stop<br>1: Run | 0 → Stop |
| **1082** | 1083 | R | Status Swimming Pool Setting Temperature | 0~80 °C(*3) | 24 °C |
| **1083** | 1084 | R | Status Swimming Pool Temperature | -80~100 °C (*1) | -127 °C |
| **1084** | 1085 | R | Status Anti Legionella Run | 0: Stop<br>1: Run | 0 → Stop |
| **1085** | 1086 | R | Status Anti Legionella Setting Temperature | 0~80 °C(*3) | 70 °C |
| **1086** | 1087 | R | Status Block menu (*6) | 0: No<br>1: Block | 0 → No |
| **1087** | 1088 | R | Status BMS Alarm | 0: No<br>1: Alarm | 0 → No |
| **1088** | 1089 | R | Central Mode | 0: Local<br>1: Air<br>2:Water<br>3: Full | 3 → Full |
| **1089** | 1090 | R | System Configuration | *bitfield — see below* | 0x00D1 = Circuit 1 Heating, DHWT, Room thermostat Circuit 1, Room thermostat Circuit 2 |
| **1090** | 1091 | R | Operation State | 0: OFF<br>1: Cool Demand -OFF (*2)<br>2: Cool Thermo-OFF (*2)<br>3: Cool Thermo-ON (*2)<br>4: Heat Demand-OFF<br>5: Heat Thermo-OFF<br>6: Heat Thermo-ON<br>7: DHW-OFF<br>8: DHW-ON<br>9: SWP-OFF<br>10: SWP-ON<br>11: Alarm | 7 → DHW-OFF |
| **1091** | 1092 | R | Outdoor ambient temperature | -80~100 °C (*1) | 23 °C |
| **1092** | 1093 | R | Water Inlet unit temperature | -80~100 °C (*1) | 23 °C |
| **1093** | 1094 | R | Water outlet unit temperature | -80~100 °C (*1) | 22 °C |
| **1094** | 1095 | R | H-LINK communication state | 0: No alarm<br>1: There is no communication with RCS or YUTAKI unit during more than 180 seconds<br>2: Data initialization | 0 → No alarm |
| **1095** | 1096 | R | Software PCB | *(blank in manual)* | 318 |
| **1096** | 1097 | R | Software LCD | *(blank in manual)* | 341 |
| **1097** | 1098 | R | Unit Capacity | 0~255 kWh — a counter that grows during operation (79 → 82 within an hour, 2026-10-23); reset / wrap behaviour unknown | 0 kWh |
| **1098** | 1099 | R | Unit Power consumption | 0~255 kWh — counter, same caveat as 1097 | 10 kWh |

### Servicing parameters (read-only) — 1200–1231

Refrigerant-circuit internals. Note the `R134a *` rows **do** return real values on this unit, despite §5.2 of the manual marking the equivalent registers "Only for YUTAKI S80".

| Addr | Reg | R/W | Description | Values / range | Seen |
|-----:|----:|:---:|-------------|----------------|------|
| **1200** | 1201 | R | Water outlet hp T° (Water outlet hp outlet unit temperature) | 0~100 °C | 21 °C |
| **1201** | 1202 | R | Ta2: Outdoor Unit Ambient Average Temp. | -80~100 °C (*1) | 22 °C |
| **1202** | 1203 | R | Ta. Second Ambient Temperature | -80~100 °C (*1) | -67 °C |
| **1203** | 1204 | R | Ta3: Second ambient average temp. | -80~100 °C (*1) | -67 °C |
| **1204** | 1205 | R | O2: Water outlet Temp. 2 (Two2) | -80~100 °C (*1) | -127 °C |
| **1205** | 1206 | R | O3: Water outlet Temp. 3 (Two3) | -80~100 °C (*1) | -127 °C |
| **1206** | 1207 | R | Tg: Gas Temperature (THMg) | -80~100 °C (*1) | -100 °C |
| **1207** | 1208 | R | TI: Liquid Temperature (THMl) | -80~100 °C (*1) | 23 °C |
| **1208** | 1209 | R | Td: Discharge Gas temp | -80~100 °C (*1) | 22 °C |
| **1209** | 1210 | R | Te: Evaporation temp | -80~100 °C (*1) | 22 °C |
| **1210** | 1211 | R | EVI: Indoor Expansion valve opening | 0~100 % | 2 % |
| **1211** | 1212 | R | EVO: Outdoor Expansion valve | 0~100 % | 0 % |
| **1212** | 1213 | R | H4: Inverter Operation frequency | 0~115 Hz (*3) | 0 Hz |
| **1213** | 1214 | R | DI: Cause of stoppage | *(blank in manual)* | 1 |
| **1214** | 1215 | R | P1: Compressor running current | 0~30 A (*3) | 0 A |
| **1215** | 1216 | R | CD: Capacity data | *(blank in manual)* | 40 |
| **1216** | 1217 | R | MVP: Mixing valve position | Only Circuit 2 | 0 |
| **1217** | 1218 | R | Defrosting | *(blank in manual)* | 0 |
| **1218** | 1219 | R | Unit model | 0: YUTAKI S<br>1: YUTAKI S COMBI<br>2: S80<br>3: M | 1 → YUTAKI S COMBI |
| **1219** | 1220 | R | Th: Water Temp. Setting (Ttwo) | -80~100 °C (*1) | 32 °C |
| **1220** | 1221 | R | Water flow level | 0~30 (0,0~3,0 m³/h) | 0 → 0.0 m³/h |
| **1221** | 1222 | R | Water pump speed | 0~100 % | 0 % |
| **1222** | 1223 | R | System status 2 | *bitfield — see below* | 0x0000 = none set |
| **1223** | 1224 | R | Alarm number | 0: No Alarm<br>XXX: Alarm number | 0 → No Alarm |
| **1224** | 1225 | R | R134a Discharge Temperature | -80~100 °C (*1) | 20 °C |
| **1225** | 1226 | R | R134a Suction temperature | -80~100 °C (*1) | 44 °C |
| **1226** | 1227 | R | R134a Discharge Pressure | 0~510 (0'00~5'10 MPa) | 90 |
| **1227** | 1228 | R | R134a Suction pressure | 0~255 (0'00~2'55 MPa) | 41 |
| **1228** | 1229 | R | R134a Compressor frequency | 0~115 Hz (*3) | 0 Hz |
| **1229** | 1230 | R | R134a Indoor Expansion valve 2 opening | 0~100 % | 8 % |
| **1230** | 1231 | R | R134a Compressor current value | 0~300 (0'00~30'0 A) | 0 |
| **1231** | 1232 | R | R134a Retry Code | *(blank in manual)* | 0 |

## Bitfields

### System Configuration — address 1089 (bitfield)

Raw value seen: `0x00D1` (209) → 0x00D1 = Circuit 1 Heating, DHWT, Room thermostat Circuit 1, Room thermostat Circuit 2

| Bit | Meaning | Set? |
|----:|---------|:----:|
| 0 | Circuit 1 Heating | ✅ |
| 1 | Circuit 2 Heating | — |
| 2 | Circuit 1 Cooling (*2) | — |
| 3 | Circuit 2 Cooling (*2) | — |
| 4 | DHWT | ✅ |
| 5 | SWP | — |
| 6 | Room thermostat Circuit 1 | ✅ |
| 7 | Room thermostat Circuit 2 | ✅ |
| 8 | Wireless setting Circuit 1 | — |
| 9 | Wireless setting Circuit 2 | — |
| 10 | Wireless room temperature Circuit 1 | — |
| 11 | Wireless room temperature Circuit 2 | — |

### System status 2 — address 1222 (bitfield)

Raw value seen: `0x0000` (0) → 0x0000 = none set

| Bit | Meaning | Set? |
|----:|---------|:----:|
| 0 | Defrost | — |
| 1 | Solar | — |
| 2 | Water Pump 1 | — |
| 3 | Water Pump 2 | — |
| 4 | Water Pump 3 | — |
| 5 | Compressor ON | — |
| 6 | Boiler ON | — |
| 7 | DHW Heater | — |
| 8 | Space Heater | — |
| 9 | Smart function input enable | — |

## Gateway self-configuration — addresses 0–63

Not documented in the manual; determined by reading the live module and re-reading to see what is stable. These describe the **gateway itself**, not the heat pump — useful for confirming you are talking to the right box.

| Addr | Meaning | Seen |
|-----:|---------|------|
| 0–2 | Hardware identifier (read via FC4) — see note | `3846-103-2` |
| 20–23 | Own IP address — **one byte per register** | `192.168.2.162` |
| 24 | Modbus TCP port | `502` |
| 25–28 | Netmask — one byte per register | `255.255.255.0` |
| 29–32 | LAN gateway — one byte per register | `192.168.2.1` |
| 50–63 | Allowed-master list, 7 slots × 2 registers — **two bytes per register** | `192.168.2.108` ×7 |

⚠ The two IP encodings differ. The gateway's own address at 20–23 uses one octet per register (`192`,`168`,`2`,`162`), while the master list at 50–63 packs two octets into each register (`0xC0A8` = `192.168`, `0x026C` = `2.108`). Decoding one with the other's rule gives nonsense.

Registers 0–2 are treated by the `hass-hitachi_yutaki` integration as a single opaque hardware identifier, not as separate fields. Its docstring example is `3846-103-56`; this unit reads `3846-103-2`. Registers 0 and 1 are therefore **the same on both units** and most likely identify the gateway type and firmware, while register 2 varies per unit — but that reading is inference, not documented fact.

**Addresses 8, 16 and 40–49 are counters, not configuration** — they increment roughly once per second and drift between reads. Do not treat them as settings; their exact meaning is unidentified.

## Quick recipes

Common things to poll, already converted:

| Want | Addr | Conversion |
|---|---:|---|
| **ECS / DHW tank temperature** | `1080` | signed, whole °C |
| DHW setpoint | `1077` | whole °C |
| DHW tank running | `1076` | 0 = Stop, 1 = Run |
| Outdoor ambient | `1091` | signed, whole °C |
| Water inlet | `1092` | signed, whole °C |
| Water outlet | `1200` | signed, whole °C — **prefer this**, fall back to `1093` |
| Room temp (circuit 1) | `1061` | ÷10 °C |
| Operation state | `1090` | enum, see table |
| Compressor frequency | `1212` | Hz (0 = compressor off) |
| Compressor current | `1214` | A |
| Unit power consumption | `1098` | kWh |
| Unit capacity delivered | `1097` | kWh |
| Alarm number | `1223` | 0 = no alarm |

⚠ **Water outlet: use 1200, not 1093.** Both are labelled "water outlet" in the manual, but 1093 is the unit-level outlet and reads incorrectly while the machine is in DHW or pool mode. Address 1200 is the heat-pump-level outlet and is correct in all modes. The `hass-hitachi_yutaki` integration reads 1200 with 1093 only as a fallback; this is not stated anywhere in the manual.

## Writing — rules used by the example app

Settled against the manual (PMML0419 rev.3, §5.3 and its footnotes) and the
[hass-hitachi_yutaki](https://github.com/alepee/hass-hitachi_yutaki) code:

- **FC6 only**, one register per request, at the *control* address (1000–1033). The status
  mirror (1050–1098) follows after the unit has taken the command.
  Verified on a Yutaki S Combi (2026-10-23): writing 61 to 1031 (anti-legionella setting) was
  accepted and the status mirror 1085 showed 61 at the next poll.
- **Central mode** (address 1088: 0 Local, 1 Air, 2 Water, 3 Full) is read-only in the manual,
  which says nothing about its effect on writes. Home Assistant users report that written values
  were reset until "central operation" was set to *Full* in the controller's installer menu
  ([forum report](https://forum.hacf.fr/t/developpement-dune-integration-custom-hitachi-yutaki-via-modbus-atw-mbs-02/51691)).
  The unit documented here reports **3 = Full** without any change by the owner. Reads work in
  every mode.
- Check **H-LINK state** (1094) = 0 before writing; 2 means the gateway is still initialising.
- **Eco mode** (1007 / 1018): **0 = ECO, 1 = Comfort**. (Some third-party notes have it inverted;
  the manual and the Home Assistant code agree on this encoding.)
- **Room setpoint** (1011 / 1022): tenths of °C, 50–350 = 5.0–35.0 °C.
- **Room temperature** (1012 / 1023): written by a *Modbus* thermostat only — enable 1010 / 1021
  first, and only when no Hitachi thermostat is fitted (footnotes *7 and *8). With a Hitachi
  thermostat (1089 bit 6 / 7 set), read the room temperature at 1061 / 1073 instead.
- **Unit mode** (1001) is global to all circuits. *Auto* (2) does not exist before line-up 2016.
- **DHW boost** (1026): write 1; the unit resets it to 0 when the boost ends.
- **Anti-legionella** (1030): set the temperature (1031) first, then write 1. Usable only if the
  function is enabled on the controller (footnote *9).
- Temperature setpoints marked *(\*3)* are limited by the unit according to its model; a write
  outside that limit is clamped or ignored by the unit.

## Cross-check

Every address here was verified against the register map in [`alepee/hass-hitachi_yutaki`](https://github.com/alepee/hass-hitachi_yutaki), a maintained Home Assistant integration for this exact gateway.

The independent source is the integration's own code — [`custom_components/hitachi_yutaki/api/modbus/registers/atw_mbs_02.py`](https://github.com/alepee/hass-hitachi_yutaki/blob/main/custom_components/hitachi_yutaki/api/modbus/registers/atw_mbs_02.py). It keeps two separate maps, `atw_mbs_02.py` and `atw_mbs_02_pre2016.py`, which is the same §5.3 / §5.2 split identified here, and its read addresses match this table exactly. That independently confirms the *register − 1* offset.

Three things come from that code rather than the manual and are folded in above: the `-127` / `-67` sentinel conventions, the water-outlet 1200-over-1093 preference, and the meaning of registers 0–2.

The integration also documents the **write/control** side (FC6, setpoints, mode changes); its conventions are used by the example app. Read its [gateway notes](https://github.com/alepee/hass-hitachi_yutaki/blob/main/docs/gateway/atw-mbs-02.md) before writing anything to a unit, and note that writes are only accepted when *central operation* is set to **Full** on the controller (installer menu).

## Footnotes (from the manual)

- (*1) Signed 16-bit, two's complement for negative values.
- (*2) Only for heating **and** cooling units.
- (*3) Value is limited by the machine according to its rank.
- (*4) Informs that the Modbus net is in alarm.
- (*5) Thermostat setting / room temperature may differ from the unit's own when using central control.
- (*6) Access to the menu on the unit controller is blocked.
- (*7) Enable when using a Modbus thermostat.
- (*8) Usable only when no Hitachi thermostat is installed.
- (*9) Usable only if the function is enabled on the LCD.

---

*Extracted from the ATW-MBS-02 manual PMML0419 §5.3 (English). Live values sampled 2026-09-20.*
