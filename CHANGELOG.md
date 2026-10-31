# Changelog

## 1.1.0 — 2026-10-31

**Library**
- **FC 23** Read/Write Multiple Registers: `ModbusRequest(readAddress, readCount, writeAddress,
  registerValues())`, `ReadWriteMultipleRegisters` on the clients.
- **FC 22** Mask Write Register, **FC 08 / 00** Return Query Data (loopback), **FC 17** Report
  Server ID, **FC 43 / 14** Read Device Identification: `MaskWriteRegister`, `ReturnQueryData`,
  `ReportServerID`, `ReadDeviceIdentification` on both clients; `ModbusRequest.ResponseBytes`,
  `DeviceObjects`, `MoreFollows`, `NextObjectID`.
- **`ModbusRTUClient`** (a `SerialConnection` subclass): Modbus **RTU** over a serial line, same
  API and events as `ModbusTCPClient`, plus `FrameTraced`. CRC-16, 3.5-character frame gap,
  answer end from its length, CRC and unit checks, broadcast writes, echo suppression for RS-485
  adapters. ⚠️ **Not tested on a real device yet** — the author does not have one.
- **`ModbusTransport`** interface implemented by both clients; `ModbusPoller.Client` accepts either.
- `ModbusTypes.CRC16`, `RTUResponseLength`, `eError.InvalidRequest`; `ModbusRequest.BuildPDU`
  (now public), `BuildRTUFrame`, `SentUnitID`.
- Self-test: 87 checks, including RTU frames and CRCs against reference values; the console test
  checks every function code live against the simulator.

**Apps**
- The airH2O app is now **VNS Modbus TCP**, in `VNS-Modbus-TCP/`.
- New **VNS Modbus RTU**, a generic serial Modbus tester (`VNS-Modbus-RTU/`) — untested on a real
  device.

**Docs** — developer guide (new functions, RTU, `ModbusTransport`), [RTU testing guide](docs/RTU_TESTING.md),
[Modbus protocol reference](docs/MODBUS_PROTOCOL.md).

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
