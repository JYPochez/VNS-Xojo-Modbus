# VNS Xojo Modbus — developer guide

How to build your own Xojo application on top of the library, step by step, followed by the
complete API reference. The Hitachi airH2O app in this repository is used as the worked example
throughout; open it next to this guide.

- [1. What you get](#1-what-you-get)
- [2. Install](#2-install)
- [3. First read in five minutes](#3-first-read-in-five-minutes)
- [4. Modbus addressing in one page](#4-modbus-addressing-in-one-page)
- [5. Reading and writing raw registers](#5-reading-and-writing-raw-registers)
- [6. Values wider than 16 bits: data types and word order](#6-values-wider-than-16-bits-data-types-and-word-order)
- [7. Describing a device as points](#7-describing-a-device-as-points)
- [8. Polling](#8-polling)
- [9. Writing safely](#9-writing-safely)
- [10. Errors and connection handling](#10-errors-and-connection-handling)
- [11. Console, Web and threads](#11-console-web-and-threads)
- [12. Testing without hardware](#12-testing-without-hardware)
- [13. Troubleshooting](#13-troubleshooting)
- [14. API reference](#14-api-reference)

---

## 1. What you get

| Class / module | Role |
|----------------|------|
| `ModbusTCPClient` | The connection. A `TCPSocket` subclass: drop it on a window, set `Address`, call `ReadHoldingRegisters`… Queue, timeouts and reconnection are handled for you. |
| `ModbusRequest` | One request and its answer (`Values()`, `ErrorCode`, `ResponseTimeMS`…). |
| `ModbusPoint` | One named value of a device: where it is (`hr1080:int16`), how to show it (scale, unit, labels), whether it may be written. |
| `ModbusPointTable` | Builds a list of points from a plain-text table — the easiest way to describe a device. |
| `ModbusPoller` | A `Timer` subclass that reads a set of points every *n* seconds, in as few requests as possible, and writes them safely. |
| `ModbusTypes` | Enums, constants and value conversion (16/32/64-bit, signed, float, word orders). |
| `ModbusSelfTest` | Checks the library without any device. |
| `ModbusClientTimer`, `ModbusPollBlock` | Internal helpers; you never use them directly. |

Supported Modbus functions: **01** read coils, **02** read discrete inputs, **03** read holding
registers, **04** read input registers, **05** write single coil, **06** write single register,
**15** write multiple coils, **16** write multiple registers. Modbus **TCP** only (no serial RTU).

Everything is pure Xojo (API 2, Xojo 2026r2.1): no plugin, no `Declare`.

## 2. Install

1. Copy the [`Modbus`](../Modbus) folder next to your project.
2. In the Xojo IDE, drag the folder into the Navigator (or *File → Import*). Nine items appear.
3. Build once. That's all: the library has no other dependency.

Keep the folder name and the item names; your code refers to `ModbusTypes.eError.Timeout` and so on.

## 3. First read in five minutes

Start the simulator that comes with the repository — no hardware needed:

```sh
python3 tools/airh2o_simulator.py --mode generic --port 5021
```

1. Drag a **`ModbusTCPClient`** from the Navigator onto your window. Name it `Device`.
2. Add a button with this `Pressed` event:

```xojo
Device.Address = "127.0.0.1"
Device.Port = 5021
Device.UnitID = 1
Device.ReadHoldingRegisters(0, 10)      ' connects automatically
```

3. Implement the `RequestCompleted` and `RequestFailed` events of `Device`:

```xojo
Sub RequestCompleted(request As ModbusRequest)
  For i As Integer = 0 To request.Values.LastIndex
    Var registerAddress As Integer = request.Address + i
    System.DebugLog("hr" + registerAddress.ToString + " = " + request.Values(i).ToString)
  Next
End Sub

Sub RequestFailed(request As ModbusRequest)
  System.DebugLog(request.ErrorMessage)
End Sub
```

4. In the window's `Closing` event, release the connection:

```xojo
Device.Close
```

Run, press the button: ten zeros appear in the Messages panel. Write a value and read it back:

```xojo
Device.WriteSingleRegister(3, 1234)
Device.ReadHoldingRegisters(0, 10)      ' queued: sent after the write is answered
```

Requests are **queued and sent one at a time**, in order. You never wait for anything: the answers
arrive as events.

## 4. Modbus addressing in one page

Modbus has four separate areas. Each one has its own addresses from 0 to 65535:

| Area | Prefix | Size | Access | Read with | Write with |
|------|--------|------|--------|-----------|------------|
| Coils | `co` | 1 bit | read / write | FC 01 | FC 05, 15 |
| Discrete inputs | `di` | 1 bit | read only | FC 02 | — |
| Holding registers | `hr` | 16 bits | read / write | FC 03 | FC 06, 16 |
| Input registers | `ir` | 16 bits | read only | FC 04 | — |

**The library always uses the 0-based address that travels on the wire.** Device manuals often
use other conventions — this is the first thing to check when values look wrong:

| The manual says | Address to use |
|-----------------|----------------|
| "Register 40001", "4x0001" (holding) | `hr0` — subtract 40001 |
| "Register 30005" (input) | `ir4` — subtract 30001 |
| "Register 1081" in a 1-based table | `hr1080` — subtract 1 (the Hitachi case) |
| "Address 0x0438" | `hr1080` — the hex value as is |

When in doubt, read a block around the expected address with `tools/modbus_probe.py` and look for
a value you know (a temperature on the device's display, a setpoint).

The **unit ID** (slave id) selects a device behind a serial gateway. Plain TCP devices usually
ignore it; leave it at 1.

## 5. Reading and writing raw registers

### Reading

```xojo
Device.ReadHoldingRegisters(1050, 49)   ' 1050 to 1098, at most 125 registers per request
Device.ReadInputRegisters(0, 3)
Device.ReadCoils(0, 16)                 ' at most 2000 bits; each Values() entry is 0 or 1
Device.ReadDiscreteInputs(0, 8)
```

The answer is a `ModbusRequest`. `request.Values()` holds one `UInt16` per register (or 0/1 per
bit), starting at `request.Address`.

### Knowing which answer is which: `tag` and callbacks

Every read and write method takes two optional arguments:

```xojo
Device.ReadHoldingRegisters(1080, 1, Nil, "dhw")      ' tag: any Variant, given back untouched

Sub RequestCompleted(request As ModbusRequest)
  If request.Tag = "dhw" Then LabelDHW.Text = request.Values(0).ToString
End Sub
```

or a **callback**, a method called for that request only, instead of the events:

```xojo
Device.ReadHoldingRegisters(1080, 1, WeakAddressOf DHWAnswered)

Private Sub DHWAnswered(request As ModbusRequest)
  If request.Succeeded Then LabelDHW.Text = request.Values(0).ToString
End Sub
```

A request with a callback **does not** raise `RequestCompleted` / `RequestFailed`. This is how
`ModbusPoller` shares a client with your own code: Xojo events accept a single handler, so the
poller uses callbacks and leaves the events to you.

### Writing

```xojo
Device.WriteSingleRegister(1025, 50)                  ' FC 06; -32768 to 65535
Device.WriteSingleCoil(3, True)                       ' FC 05

Var registerValues() As Integer = Array(10, 20, 30)
Device.WriteMultipleRegisters(100, registerValues)    ' FC 16, at most 123

Var coilValues() As Boolean = Array(True, False, True)
Device.WriteMultipleCoils(0, coilValues)              ' FC 15, at most 1968
```

A write answer has no values; `request.Succeeded` tells whether the device accepted it.

### Full control: `ModbusRequest` + `Send`

```xojo
Var request As New ModbusRequest(ModbusTypes.eFunction.ReadHoldingRegisters, 0, 10)
request.UnitID = 3                ' this request only; -1 (default) uses Device.UnitID
request.Tag = "meter 3"
Device.Send(request)
```

Invalid arguments (address outside 0–65535, too many registers, a value that does not fit) raise
`InvalidArgumentException` at once: they are programming errors, not device errors.

## 6. Values wider than 16 bits: data types and word order

A register is 16 bits. Bigger values span 2 registers (32-bit integers, `Float32`) or 4
(`Float64`). Devices disagree on the order of those registers and bytes, so the library supports
the four layouts, named after the bytes A (most significant) to D:

| `eWordOrder` | Register 1 | Register 2 | Used by |
|--------------|-----------|-----------|---------|
| `ABCD` | A B | C D | the Modbus standard (big-endian); the default |
| `CDAB` | C D | A B | "word swap" — very common in meters and PLCs |
| `BADC` | B A | D C | byte swap |
| `DCBA` | D C | B A | fully little-endian |

```xojo
' energy counter at ir30, 32-bit float, word-swapped
Var kWh As Double = request.ValueAt(0, ModbusTypes.eDataType.Float32, ModbusTypes.eWordOrder.CDAB)

' a signed temperature in one register
Var celsius As Double = request.ValueAt(0, ModbusTypes.eDataType.Signed16)
```

To write such a value, encode it first:

```xojo
Var words() As UInt16 = ModbusTypes.EncodeValue(21.5, ModbusTypes.eDataType.Float32, ModbusTypes.eWordOrder.CDAB)
Var request As New ModbusRequest(ModbusTypes.eFunction.WriteMultipleRegisters, 200, words)
Device.Send(request)
```

If a 32-bit value looks absurd (1.2E-38, 1 073 741 824…), try the other word orders: the right one
gives a plausible number.

## 7. Describing a device as points

Raw registers are fine for a test. For a real application, describe each value once — where it
is, how to show it, whether it may be written — and let the library do the rest. That
description is a **point**.

### One point

```xojo
Var p As New ModbusPoint("dhw.temp", "hr1080:int16", 1.0, "°C")
p.Label = "DHW temperature"
p.InvalidValues.Add(-127)                 ' the device's "no sensor" value
```

The location string is `<area><address>[.<bit>][:<type>][:<word order>]`:

| Location | Meaning |
|----------|---------|
| `hr1080` | holding register 1080, unsigned 16-bit (default) |
| `hr1080:int16` | signed 16-bit |
| `ir30:float32:cdab` | input registers 30–31, float, word-swapped |
| `hr500:uint32` | holding registers 500–501, unsigned 32-bit, ABCD |
| `hr1089.4` | bit 4 of holding register 1089 |
| `co5`, `di12` | one coil, one discrete input |

Types: `uint16`, `int16`, `uint32`, `int32`, `float32` (or `float`), `float64` (or `double`),
`bool` / `bit`. Orders: `abcd`, `cdab`, `badc`, `dcba`.

What a point gives you after a read:

| Member | Example |
|--------|---------|
| `RawValue` | 235 |
| `Value` | 23.5 (= raw × `Scale` + `ValueOffset`) |
| `DisplayText` | `23.5 °C`, `Run`, `Defrost, Compressor`, `n/a`, `—` |
| `HasValue`, `IsValid`, `LastUpdate`, `ErrorMessage` | state of the last read |

`DisplayText` uses, in this order: the label of a coded value (`AddEnumLabel(1, "Run")`), the
labels of the bits that are set (`AddBitLabel(5, "Compressor")`), otherwise the scaled value with
its `Unit` and `Decimals`, in the user's locale. A raw value listed in `InvalidValues` shows as
`n/a`; a point never read shows `—`.

### A whole device as a table

`ModbusPointTable.Parse` turns plain text into points, one line per point, fields separated by
semicolons. This is how the airH2O app describes its 123 registers
(`HitachiAirH2O/AirH2OPoints.kPointTable`):

```
# name;location;scale;unit;category;label;access;min;max;labels;invalid;decimals
system.outdoor;hr1091:int16;1;°C;System;Outdoor temperature;R;;;;-127|-67
c1.roomTemp;hr1061;0.1;°C;Circuit 1;Room temperature;R;;;;65535
dhw.run;hr1076;1;;DHW;DHW;R;;;0=Stop|1=Run;65535
ctl.dhw.setpoint;hr1025;1;°C;DHW;DHW setpoint setting;W;0;80;;65535
svc.status;hr1222;1;;Servicing;Active components;R;;;b0=Defrost|b5=Compressor;65535
```

| # | Column | Notes |
|---|--------|-------|
| 0 | name | unique key, used by `FindPoint` and `WritePoint` |
| 1 | location | as above |
| 2 | scale | empty = 1; **always a dot** as decimal separator |
| 3 | unit | |
| 4 | category | free grouping, e.g. a tab of your window |
| 5 | label | shown to the user; empty = name |
| 6 | access | `R` read-only, `W` writable |
| 7–8 | min, max | accepted range for writes, in engineering units; empty = no check |
| 9 | labels | coded values `0=Stop\|1=Run` or bits `b0=Defrost\|b5=Compressor` |
| 10 | invalid | raw values meaning "no data", e.g. `-127\|-67\|65535` |
| 11 | decimals | digits shown; empty = automatic from the scale |

Empty lines and lines starting with `#` are ignored. A bad line raises
`InvalidArgumentException` with its line number.

```xojo
Var points() As ModbusPoint = ModbusPointTable.Parse(kMyDeviceTable)
```

Store the table in a string constant of a module of your app, as `AirH2OPoints` does: the
whole knowledge of the device is then data, readable and reviewable, and the code stays generic.

**Translated labels.** `Parse` takes an optional translator, called for every label, category and
coded-value text:

```xojo
Var points() As ModbusPoint = ModbusPointTable.Parse(kMyDeviceTable, AddressOf TranslateLabel)

Private Function TranslateLabel(text As String) As String
  Return mGermanLabels.Lookup(text, text).StringValue
End Function
```

## 8. Polling

`ModbusPoller` is a `Timer` subclass. Drop one on the window next to the client:

```xojo
' window Opening
Poller.Client = Device
For Each p As ModbusPoint In ModbusPointTable.Parse(kMyDeviceTable)
  Poller.AddPoint(p)
Next
Poller.Period = 5000                      ' ms
Poller.Start                              ' reads now, then every Period

' Poller.PointsUpdated
For Each p As ModbusPoint In Poller.Points
  ' refresh your display from p.Label, p.DisplayText…
Next
```

How the poller reads: points are grouped by area and address. Neighbours closer than `MaxGap`
unused addresses (default 8) are read in the same request, up to `MaxBlockRegisters` (125) or
2000 bits. The airH2O map — 123 points spread over 1000–1098, 1200–1231 and the gateway block —
takes 5 requests per poll.

- `PointsUpdated` fires once per poll, when every block has answered or failed.
- `PollFailed(request)` fires for each block that failed; its points are marked
  (`HasValue = False`, `ErrorMessage`).
- A poll is skipped while the previous one is still running, so a slow device is never flooded.
- `FindPoint("dhw.temp")` returns a point by name.

Devices that refuse long reads: lower `MaxBlockRegisters`. Devices that answer an exception for
an unmapped address inside a block: set `MaxGap = 0`.

## 9. Writing safely

```xojo
Poller.WritePoint("ctl.dhw.setpoint", 50)

' Poller.WriteCompleted(target As ModbusPoint, succeeded As Boolean, message As String)
```

`WritePoint`:

1. finds the point and checks that it is writable (`Writable`, and a coil or a whole holding
   register);
2. checks the value against `MinValue`–`MaxValue` and converts it (`Scale`, data type, word order);
3. writes it — FC 06 for one register (`PreferSingleRegisterWrite`, the most widely supported),
   otherwise FC 16, FC 05 for a coil — at `WriteAddress` if the device has a separate setpoint
   register, otherwise at `Address`;
4. reads all points again (`RefreshAfterWrite`), so the display shows what the device really did.

Steps 1–2 raise `InvalidArgumentException`; catch it and show the message.

When the device is real equipment, put **one** write path in your application and make every
write go through it. The airH2O app (`MainWindow.EditSelectedPoint`) is a model:

- writing must be enabled explicitly, with a confirmation, once per session;
- the client must be connected, and the device's own health register (H-LINK) must be OK;
- the user sees the current value, the register, the allowed range and any warning, and confirms;
- sensitive commands (stop, mode change…) get an extra warning (`AirH2OPoints.IsSensitive`);
- the result stays visible after the automatic refresh.

## 10. Errors and connection handling

Every failed request carries its reason:

| `request.ErrorCode` | Meaning |
|---------------------|---------|
| `Timeout` | no answer within `TimeoutMS` (3000) |
| `ExceptionResponse` | the device refused; `ExceptionCode`: 1 illegal function, 2 illegal address, 3 illegal value, 4 device failure, 6 busy, 10/11 gateway errors |
| `InvalidResponse` | the answer did not match the request |
| `NotConnected` | no address set |
| `ConnectFailed`, `ConnectionLost` | the connection failed or broke while the request waited |
| `Cancelled` | `Disconnect`, `Close` or `CancelPending` |

`request.ErrorMessage` holds the English text (`ModbusTypes.ErrorText`,
`ModbusTypes.ExceptionText`).

The connection:

- `Connect` is optional: the first request connects. `ConnectTimeoutMS` (5000) limits the wait.
  After an explicit `Disconnect` or `Close`, requests fail with `NotConnected` until you call
  `Connect` again — nothing reconnects behind your back.
- `Disconnected(reason)` tells why the connection ended; `LastErrorMessage` gives the socket error
  in words (`ModbusTypes.SocketErrorText`: "Connection refused", "No route to the device"…).
- With `AutoReconnect` (default), the client reconnects by itself: first after 1 s, then every
  `ReconnectDelayMS` (5000). `Disconnect` stops that.
- When the connection ends, the request in flight and every queued request fail with the reason;
  nothing waits forever.
- After `MaxConsecutiveTimeouts` (3) timeouts in a row, the connection is considered half-open
  (device rebooted, cable pulled — TCP does not always notice) and is opened again.
- An exception raised in your event handler or callback does not stall the queue: the next
  request is still sent, then the exception reaches you.
- A late answer to a request that already timed out is recognised by its transaction id and
  ignored.
- `InterRequestDelayMS` adds a pause between requests for serial gateways that need it.
- Call `Close` from the owner's `Closing` event: it stops the timers and the reconnection.

Raw requests are not split: a read of more than 125 registers raises an exception. The poller
splits for you.

Write answers are checked: the device must echo the address and the value (FC 05/06) or the
quantity (FC 15/16), otherwise the request fails with `InvalidResponse`. NaN, infinity and values
outside the data type are refused before anything is sent.

## 11. Console, Web and threads

> Tested on macOS: Desktop (the airH2O app) and Console ([`tests/ConsoleLiveTest`](../tests/ConsoleLiveTest),
> which uses exactly the pattern below). The Web and thread notes follow from how `TCPSocket` and
> `Timer` work in Xojo and have not been tested yet — reports welcome.

**Events need the event loop.** The client and the poller are a `TCPSocket` and a `Timer`: their
events run from the application's event loop. Desktop and Web apps have one; a console app must
keep it turning:

```xojo
' Console App.Run
mDevice = New MyMeterClient            ' a subclass of ModbusTCPClient that implements the events
mDevice.Address = "192.168.1.50"
mDevice.ReadHoldingRegisters(0, 10)
While Not mDone
  App.DoEvents(10)
Wend
```

Outside a window, implement the events in a **subclass** (`MyMeterClient` inherits
`ModbusTCPClient`; `MyPoller` inherits `ModbusPoller`), or use per-request callbacks. Events
accept a single handler, so one client serves one owner — share it through callbacks.

**Web**: create the client per session (a property of the `WebSession` or of a page), never as a
global shared by all sessions.

**Threads**: the client is not thread-safe. Use it from the main thread; from a cooperative
`Thread`, only through methods that queue a request. Never from a preemptive thread.

## 12. Testing without hardware

`tools/airh2o_simulator.py` (Python 3, no dependency) is a Modbus TCP server:

```sh
# a plain device: 65536 coils / inputs / registers, all function codes, all zero at start
python3 tools/airh2o_simulator.py --mode generic --port 5021

# the Hitachi ATW-MBS-02 gateway, with realistic values and its quirks
python3 tools/airh2o_simulator.py --port 5020 --drift --verbose
```

`tools/modbus_probe.py` reads (never writes) any device: `python3 tools/modbus_probe.py
192.168.1.50 0 20`.

`ModbusSelfTest.Run` checks the library itself — conversions in every word order, the exact bytes
of each request, answer decoding, points, the table parser — and returns one PASS/FAIL line per
check. Run it after changing the library:

```xojo
For Each line As String In ModbusSelfTest.Run
  System.DebugLog(line)
Next
```

## 13. Troubleshooting

| Symptom | Look at |
|---------|---------|
| Every value is off by one register | 0-based vs 1-based addresses (§ 4) |
| Huge or tiny numbers for 32-bit values | word order (§ 6) |
| `Illegal function (exception 1)` | the device does not support that function code: try FC 03 instead of 04, FC 06 instead of 16 (`PreferSingleRegisterWrite`) |
| `Illegal data address (exception 2)` on a poll | a block crosses unmapped addresses: lower `MaxGap` |
| `65535` or `-1` where a value is expected | the device's "no data" value: add it to `InvalidValues` |
| Timeouts on every request | address, port, firewall, unit id behind a gateway; some gateways accept only listed client IPs |
| macOS: *No route to the device (65)* | Local Network permission — see the [README](../README.md#troubleshooting) |

## 14. API reference

Conventions: addresses are 0-based; times are in milliseconds; "raises" means
`InvalidArgumentException` unless stated otherwise.

### ModbusTCPClient (inherits TCPSocket)

**Properties**

| Property | Default | Description |
|----------|---------|-------------|
| `Address` | | IP address or host name of the device (inherited) |
| `Port` | 502 | TCP port (inherited) |
| `UnitID` | 1 | unit id used by requests whose `UnitID` is -1 |
| `TimeoutMS` | 3000 | wait for each answer |
| `ConnectTimeoutMS` | 5000 | wait for the connection to open |
| `AutoReconnect` | True | reconnect after a lost or failed connection |
| `ReconnectDelayMS` | 5000 | delay between automatic reconnections (the first one waits 1 s) |
| `InterRequestDelayMS` | 0 | pause after each answer before the next request |
| `MaxConsecutiveTimeouts` | 3 | timeouts in a row before reconnecting; 0 = never |
| `LastErrorMessage` | | text of the last connection error |
| `State` | | `ModbusTypes.eConnectionState`: Disconnected, Connecting, Connected (read-only) |
| `PendingCount` | | requests waiting or in flight (read-only) |

**Methods**

| Method | Description |
|--------|-------------|
| `Connect()` | open the connection (optional: requests connect by themselves, except after `Disconnect`) |
| `Disconnect()` | close; stop reconnecting; pending requests fail with `Cancelled` |
| `Close()` | `Disconnect` and stop every timer — call it from the owner's `Closing` |
| `ReadCoils(startAddress, count, [callback], [tag])` | FC 01, 1–2000 bits |
| `ReadDiscreteInputs(startAddress, count, [callback], [tag])` | FC 02, 1–2000 bits |
| `ReadHoldingRegisters(startAddress, count, [callback], [tag])` | FC 03, 1–125 registers |
| `ReadInputRegisters(startAddress, count, [callback], [tag])` | FC 04, 1–125 registers |
| `WriteSingleCoil(coilAddress, newValue As Boolean, [callback], [tag])` | FC 05 |
| `WriteSingleRegister(registerAddress, newValue As Integer, [callback], [tag])` | FC 06, -32768 to 65535 |
| `WriteMultipleCoils(startAddress, coilValues() As Boolean, [callback], [tag])` | FC 15, 1–1968 |
| `WriteMultipleRegisters(startAddress, registerValues() As Integer, [callback], [tag])` | FC 16, 1–123 |
| `Send(request As ModbusRequest)` | queue a request built yourself |
| `CancelPending()` | fail every queued request with `Cancelled` (the one in flight continues) |

`callback` is a `ModbusTypes.RequestCallback`; `tag` is any `Variant`. `HandleTimer` is internal.

**Events**

| Event | When |
|-------|------|
| `Connected()` | the connection is open |
| `Disconnected(reason As ModbusTypes.eError)` | the connection ended; `None` after `Disconnect` |
| `RequestCompleted(request As ModbusRequest)` | a request without callback succeeded |
| `RequestFailed(request As ModbusRequest)` | a request without callback failed |

### ModbusRequest

| Member | Description |
|--------|-------------|
| `Constructor(code, startAddress, count)` | read request (FC 01–04); raises for an invalid address or count |
| `Constructor(code, startAddress, writeValues() As UInt16)` | write request (FC 05, 06, 15, 16) |
| `FunctionCode`, `Address`, `Quantity` | what is asked |
| `UnitID` | -1 = the client's |
| `Values() As UInt16` | registers read (or to write); 0/1 per bit for coils and inputs |
| `ValueAt(offset, dataType, [order]) As Double` | decode a value from `Values` |
| `Succeeded`, `IsDone`, `IsWrite` | state (read-only computed) |
| `ErrorCode`, `ErrorMessage`, `ExceptionCode` | why it failed |
| `ResponseTimeMS` | round trip of the answer |
| `Callback`, `Tag` | yours |
| `TransactionID`, `SentMicroseconds`, `BuildFrame`, `ParseResponse`, `Fail` | used by the client |

### ModbusPoint

| Member | Description |
|--------|-------------|
| `Constructor(pointName, location, [factor = 1.0], [unitText])` | raises for a bad location, a wide type on a coil / input / bit, or a value that would end past address 65535 |
| `Name`, `Label`, `Category`, `Unit`, `Tag` | identity and display |
| `Area`, `Address`, `BitIndex`, `DataType`, `WordOrder` | where and how (set by the location) |
| `Scale`, `ValueOffset`, `Decimals` | value = raw × Scale + ValueOffset; `Decimals` -1 = automatic |
| `Writable`, `MinValue`, `MaxValue`, `WriteAddress` | write rules; `IsWritable` = Writable and a coil or whole holding register |
| `InvalidValues() As Double` | raw values meaning "no data" |
| `RawValue`, `Value`, `HasValue`, `IsValid`, `LastUpdate`, `ErrorMessage` | last read |
| `DisplayText()`, `FormattedValue()` | text for the user |
| `AddEnumLabel(rawValue, label)`, `EnumLabel(rawValue)`, `EnumValues()`, `HasEnumLabels` | coded values |
| `AddBitLabel(bit, label)`, `BitLabels()` | bitfields |
| `EncodeForWrite(newValue) As UInt16()` | range check + conversion; raises |
| `RegisterCount()`, `Update(blockValues(), index)`, `MarkFailed(message)` | used by the poller |

### ModbusPointTable (module)

| Member | Description |
|--------|-------------|
| `Parse(table As String, [translator]) As ModbusPoint()` | one point per line (§ 7); raises with the line number |
| `Translator` | delegate `Function (text As String) As String` |

### ModbusPoller (inherits Timer)

| Member | Description |
|--------|-------------|
| `Client As ModbusTCPClient` | the connection to use |
| `Period`, `RunMode` | inherited from `Timer` |
| `MaxGap` (8), `MaxBlockRegisters` (125) | grouping of reads |
| `PreferSingleRegisterWrite` (True), `RefreshAfterWrite` (True) | write behaviour |
| `IsPolling` | a poll is waiting for answers (read-only) |
| `AddPoint(newPoint)` | raises if the name is already used |
| `FindPoint(pointName) As ModbusPoint` | Nil if unknown |
| `Points() As ModbusPoint()` | in the order added |
| `RemoveAllPoints()` | |
| `Start()`, `Stop()`, `PollNow()` | |
| `WritePoint(pointName, newValue As Double)` | § 9; raises |
| event `PointsUpdated()` | a poll finished |
| event `PollFailed(request As ModbusRequest)` | a block failed |
| event `WriteCompleted(target As ModbusPoint, succeeded As Boolean, message As String)` | a write finished |

### ModbusTypes (module)

**Enums**

| Enum | Values |
|------|--------|
| `eArea` | Coil, DiscreteInput, HoldingRegister, InputRegister |
| `eFunction` | ReadCoils = 1, ReadDiscreteInputs = 2, ReadHoldingRegisters = 3, ReadInputRegisters = 4, WriteSingleCoil = 5, WriteSingleRegister = 6, WriteMultipleCoils = 15, WriteMultipleRegisters = 16 |
| `eDataType` | Bit, Unsigned16, Signed16, Unsigned32, Signed32, Float32, Float64 |
| `eWordOrder` | ABCD, CDAB, BADC, DCBA |
| `eError` | None, NotConnected, ConnectFailed, ConnectionLost, Timeout, ExceptionResponse, InvalidResponse, Cancelled |
| `eConnectionState` | Disconnected, Connecting, Connected |

**Methods**

| Method | Description |
|--------|-------------|
| `DecodeValue(registers(), index, dataType, [order]) As Double` | raises `OutOfBoundsException` past the end |
| `EncodeValue(value, dataType, [order]) As UInt16()` | raises if the value does not fit |
| `RegisterCount(dataType) As Integer` | 1, 2 or 4 |
| `ToSigned16(value) As Integer` | 65409 → -127 |
| `AreaPrefix(area) As String`, `AreaReadFunction(area) As eFunction` | |
| `ErrorText(code)`, `ExceptionText(code)`, `SocketErrorText(code)` | English texts |

**Delegate** `RequestCallback(request As ModbusRequest)`.

**Constants** `kDefaultPort` 502, `kMaxReadRegisters` 125, `kMaxReadBits` 2000,
`kMaxWriteRegisters` 123, `kMaxWriteBits` 1968, `kVersion`.

### ModbusSelfTest (module)

`Run() As String()` — one line per check and a summary; `FailureCount() As Integer`.
