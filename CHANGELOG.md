# Changelog

## 1.0.0 — 2026-10-23

First public release.

**Library (`Modbus/`)**
- Modbus TCP client (`ModbusTCPClient`, a `TCPSocket` subclass): function codes 01, 02, 03, 04,
  05, 06, 15, 16; request queue with transaction-ID matching; response and connect timeouts;
  automatic reconnection (first retry after 1 s); half-open connection detection
  (`MaxConsecutiveTimeouts`); optional pause between requests; readable socket and Modbus
  exception texts.
- Values of 16, 32 and 64 bits — signed, unsigned, float — in the four word orders.
- `ModbusPoint`: named values from locations such as `hr1080:int16`, `ir30:float32:cdab`,
  `co5`, `hr1089.4`, with scaling, units, labels for coded values and bitfields, "no data" values
  and write ranges.
- `ModbusPointTable`: a whole device described as a plain-text table, optional label translator.
- `ModbusPoller` (a `Timer` subclass): reads every point in as few requests as possible, writes
  values with range checks and reads back.
- `ModbusSelfTest`: 58 device-free checks.

**Example app (`HitachiAirH2O/`)** — Hitachi airH2O / Yutaki heat pump through the ATW-MBS-02
gateway: 123 registers, sections hidden when the function is not fitted, guarded writes with
confirmation, remembered settings. Tested on a Yutaki S Combi (reads and writes).

**Tools and tests** — Modbus TCP simulator (generic and airH2O), read-only probe, console test
project covering every function code.

**Documentation** — README, [developer guide](docs/DEVELOPER_GUIDE.md) with API reference,
[Hitachi register map](docs/HITACHI_REGISTERS.md).

Tested on macOS (desktop and console). Windows, Linux and Web are expected to work but have not
been tried yet.
