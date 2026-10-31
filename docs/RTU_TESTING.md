# Testing Modbus RTU — guide for testers

> ## ⚠️ NOT TESTED ON A REAL DEVICE YET
>
> The RTU part of VNS Xojo Modbus (the `ModbusRTUClient` class and the **VNS Modbus RTU** app)
> has **not been tested with a real Modbus RTU device**: the author does not have a serial Modbus
> device. Your test is the first real one — thank you.

The RTU frames, CRC-16 values and answer lengths are checked by the library's self-test against
reference frames, so the encoding should be right. What only a real line can show is the
behaviour around it: serial adapters and drivers, timing, echo, how real devices answer.

## What you need

- A computer with **Xojo 2026r2.1** or later (macOS, Windows or Linux — any report is useful).
- A **Modbus RTU device** (meter, PLC, inverter, sensor, relay board…) and its documentation: the
  **register list**, the **unit id** (slave address) and the **serial settings** (baud rate,
  parity, stop bits).
- A **serial adapter**: usually USB to RS-485 (two wires A / B, plus ground), sometimes RS-232.

## Wiring

- RS-485: **A to A, B to B**, and connect the signal grounds. Some makers swap the A/B labels: if
  nothing answers at all, swap the two wires — it does no harm.
- On a short bench cable no termination resistor is needed; on a long line, 120 Ω at both ends.
- One unit id per device on the line; every device on the line uses the same baud rate and format.

## Run the app

1. Open `VNS-Modbus-RTU/VNS-Modbus-RTU.xojo_project` in Xojo and press **Run**.
2. **Port**: choose the adapter (press **Refresh** after plugging it in). On macOS it is usually
   named like `usbserial-…`; on Windows `COM3`, `COM4`…; on Linux `ttyUSB0`.
3. **Baud** and **Format**: as written in the device's documentation. Modbus default: 19200 8E1.
   Many devices use 9600 8N1.
4. **Unit**: the device's unit id (1–247).
5. Press **Open**.

## Test list

Do what applies to your device; skip the rest. After each step, note *OK* or what happened.

| # | Test | Expected |
|---|------|----------|
| 0 | **08 Diagnostics: loopback**, Values `0x1234` — the safest first test, it touches no register (not every device supports it) | "Loopback OK" with 4660 / 0x1234, or "Illegal function (exception 1)" if unsupported |
| 0b | **43 Read device identification**, Count 1, Address 0 | Vendor, product code, revision — or exception 1 if unsupported |
| 0c | **17 Report server ID** | Some bytes (often ending with FF), or exception 1 |
| 1 | **03 Read holding registers** at an address from the device's list, Count 1 | One value, the same as the device shows or documents |
| 2 | Same, **Count 10** | Ten values |
| 3 | **04 Read input registers** (if the device has input registers) | Values |
| 4 | **01 Read coils** / **02 Read discrete inputs** (if the device has them) | 0 / 1 values |
| 5 | Read an address that **does not exist** on the device | "Illegal data address (exception 2)" — this proves exceptions work |
| 6 | Wrong **unit id** (one that is not on the line) | "No response from the device (timeout)" after the timeout |
| 7 | **06 Write single register** — only to a register that is safe to change; read it back with 03 | "Write accepted", and the new value is read back |
| 8 | **16 Write multiple registers** (safe registers only), read back | Same |
| 9 | **05 / 15 Write coils** (safe coils only), read back with 01 | Same |
| 10 | **23 Read/write multiple registers** (if the device supports it — many do not) | Values read, or "Illegal function (exception 1)" if not supported |
| 10b | **22 Mask write register** (safe register only), Values `0xFFFE, 0` (clears bit 0), read back | The register without bit 0 |
| 11 | Send several reads quickly one after the other | Every one answered, none mixed up |
| 12 | Unplug the adapter while the port is open, then send | An error message; the app keeps working after **Open** again |

⚠️ **Only write to registers you know are safe to change** on your device. A wrong write can
change how a machine behaves.

## If nothing answers

Look at the **trace** on the right:

- **Only TX lines**: the request leaves but nothing comes back. Check, in this order: wiring
  (swap A/B), unit id, baud rate and format, power of the device.
- **TX, then an RX line identical to the TX**: your adapter echoes what it sends. Tick
  **Adapter echoes the frames it sends** and try again.
- **RX lines that look like garbage**: wrong baud rate or format.
- **"CRC error in the answer"**: noise on the line, or wrong format. Note it and send the log —
  this is exactly what needs a real test.
- **"Answer from another unit id"**: another device answered; check the unit ids on the line.

Timing: the timeout counts from the end of the request (default 1000 ms). Slow devices may need
2000 ms or more.

## Send the results

1. Press **Save log…** (or **Copy log** and paste it in a message). The log contains the app and
   library versions, the platform, the settings and every frame sent and received — no personal
   data.
2. Add, in a few lines: the device (maker / model), the adapter, the operating system, and which
   tests of the list worked or not.
3. Send it to the author, or open an issue on
   [GitHub](https://github.com/JYPochez/VNS-Xojo-Modbus/issues).
