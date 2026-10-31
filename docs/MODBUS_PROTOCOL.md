# Modbus protocol — a practical reference

A summary, in our own words, of the parts of the Modbus protocol that VNS Xojo Modbus implements.
It is meant to be read next to the library: every byte layout below is what the library sends and
expects. The authoritative documents are published free by the Modbus Organization
([modbus.org — specifications](https://modbus.org/modbus-specifications)):

- *Modbus Application Protocol Specification V1.1b3* — the function codes (the "PDU").
- *Modbus Messaging on TCP/IP Implementation Guide V1.0b* — Modbus TCP.
- *Modbus over Serial Line Specification and Implementation Guide V1.02* — Modbus RTU.

## 1. The model

A **client** (master) sends a **request**; a **server** (slave, device) sends back one **answer**:
either the normal answer or an **exception**. The heart of both is the **PDU** (protocol data
unit): one **function code** byte followed by its data. The PDU is the same over TCP and over a
serial line; only the envelope around it differs (§ 3, § 4). A PDU is at most 253 bytes.

All 16-bit values in a PDU — addresses, quantities, register contents — are sent **big-endian**,
high byte first.

## 2. Data model and addresses

| Area | Prefix in the library | Item | Access | Read | Write |
|------|----------------------|------|--------|------|-------|
| Coils | `co` | 1 bit | read / write | 01 | 05, 15 |
| Discrete inputs | `di` | 1 bit | read only | 02 | — |
| Holding registers | `hr` | 16 bits | read / write | 03 | 06, 16, 22, 23 |
| Input registers | `ir` | 16 bits | read only | 04 | — |

Each area has its own addresses, **0 to 65535**. The address in the PDU is **0-based**. Device
manuals often number from 1 or with a prefix: "register 40001" or "4x0001" is holding register
address **0**, "30005" is input register **4**, "register 1081" in a 1-based table is address
**1080**. The library always uses the 0-based address.

## 3. Modbus TCP

The PDU is preceded by the 7-byte **MBAP header**; the device listens on TCP port **502** by
default.

| Bytes | Field | Notes |
|-------|-------|-------|
| 2 | Transaction id | Chosen by the client, copied in the answer: matches answer to request |
| 2 | Protocol id | Always 0 |
| 2 | Length | Number of bytes that follow: unit id + PDU |
| 1 | Unit id | Selects a device behind a gateway; plain TCP devices usually ignore it |
| n | PDU | Function code + data |

Example — read 2 holding registers from address 1080, transaction 7, unit 1:
`00 07  00 00  00 06  01  03 04 38 00 02`.

There is no checksum: TCP already guarantees the bytes.

## 4. Modbus RTU (serial line)

| Bytes | Field |
|-------|-------|
| 1 | Address of the device (unit id) |
| n | PDU |
| 2 | CRC-16, **low byte first** |

- **Unit id**: 1 to 247 for devices; **0 is broadcast** — every device executes a write and none
  answers; 248–255 are reserved.
- **Character**: 11 bits on the line — start bit, 8 data bits, parity, stop bit. The standard
  format is **8E1** (even parity, 1 stop bit) at **19200** baud; without parity, 2 stop bits keep
  11 bits (8N2), though many devices use 8N1.
- **Frame boundaries**: there is no length field. A frame ends with a silence of at least **3.5
  character times**; inside a frame, characters may not be separated by more than 1.5 character
  times. Above 19200 baud the specification fixes these times at 1.75 ms and 0.75 ms. The library
  finds the end of an answer from its function code and byte count (§ 5) and waits 3.5 character
  times between frames.
- **CRC-16 (Modbus)**: start with FFFF; for each byte, XOR it into the low byte, then 8 times shift
  right and, when the bit shifted out was 1, XOR with A001. The result is sent low byte first.
  Example: `01 03 00 00 00 0A` → CRC `C5 CD`, frame `01 03 00 00 00 0A C5 CD`.

## 5. Function codes

Notation: `addr` = 2-byte address, `qty` = 2-byte quantity, `n` = 1-byte byte count. "RTU
length" is the length of the normal answer frame on a serial line (unit + PDU + CRC).

| FC | Name | Request PDU | Normal answer PDU | RTU length |
|----|------|-------------|-------------------|------------|
| 01 | Read Coils | `01 addr qty` (qty 1–2000) | `01 n bits…` — 8 coils per byte, first coil in bit 0 | 5 + n |
| 02 | Read Discrete Inputs | `02 addr qty` (1–2000) | `02 n bits…` | 5 + n |
| 03 | Read Holding Registers | `03 addr qty` (1–125) | `03 n words…` (n = 2 × qty) | 5 + n |
| 04 | Read Input Registers | `04 addr qty` (1–125) | `04 n words…` | 5 + n |
| 05 | Write Single Coil | `05 addr FF00` (on) or `0000` (off) | echo of the request | 8 |
| 06 | Write Single Register | `06 addr value` | echo of the request | 8 |
| 08 / 00 | Diagnostics — Return Query Data | `08 0000 data…` | echo of the request (loopback) | same as the request |
| 15 | Write Multiple Coils | `0F addr qty n bits…` (qty 1–1968) | `0F addr qty` | 8 |
| 16 | Write Multiple Registers | `10 addr qty n words…` (qty 1–123) | `10 addr qty` | 8 |
| 17 | Report Server ID | `11` | `11 n id bytes…` — device-specific; usually ends with a run indicator (FF = running) | 5 + n |
| 22 | Mask Write Register | `16 addr andMask orMask` | echo of the request | 10 |
| 23 | Read/Write Multiple Registers | `17 readAddr readQty writeAddr writeQty n words…` (read 1–125, write 1–121) | `17 n words…` — the registers read; the write happens first | 5 + n |
| 43 / 14 | Read Device Identification | `2B 0E category objectId` | `2B 0E category conformity more next count` then per object `id length text` | parsed from the objects |

Details:

- **FC 22** — the device stores `(current AND andMask) OR (orMask AND NOT andMask)`. To set bit
  *b*: andMask = FFFF without bit *b*, orMask = bit *b*. To clear it: same andMask, orMask = 0.
  One request instead of read-modify-write, so no other client can change the register in between.
- **FC 08** — only sub-function 00 (*Return Query Data*) is implemented: the device returns the
  request unchanged. The other sub-functions (counters, restart…) are serial-line maintenance
  functions. FC 08, 11, 12 and 17 are defined for serial lines; TCP devices may refuse them.
- **FC 43 / MEI 14** — `category` 1 = basic (objects 0–2: vendor name, product code, major/minor
  revision; mandatory), 2 = regular (adds 3 vendor URL, 4 product name, 5 model name, 6 user
  application name), 3 = extended (device-specific objects 0x80–0xFF), 4 = one specific object
  (`objectId`). When an answer does not hold every object, `more` = FF and `next` gives the object
  to ask for next. The library parses the objects into `ModbusRequest.DeviceObjects`; the RTU app
  asks for the rest automatically.

Not implemented (rarely used): 07 Read Exception Status, 08 other sub-functions, 11 / 12 Get Comm
Event Counter / Log, 20 / 21 Read / Write File Record, 24 Read FIFO Queue, 43 / 13 CANopen.

## 6. Exceptions

An exception answer is `function code + 80h` followed by one **exception code**: for example
`83 02` for a refused FC 03, `AB 01` for a refused FC 43. RTU length: 5.

| Code | Name | Usual meaning |
|------|------|---------------|
| 01 | Illegal function | The device does not support this function code |
| 02 | Illegal data address | The address (or address + quantity) does not exist |
| 03 | Illegal data value | A value or a quantity is not acceptable |
| 04 | Server device failure | The device failed while executing the request |
| 05 | Acknowledge | Accepted, still processing (long operations) |
| 06 | Server device busy | Try again later |
| 08 | Memory parity error | File record functions |
| 0A | Gateway path unavailable | A gateway cannot reach the target |
| 0B | Gateway target device failed to respond | The device behind a gateway did not answer |

A request with no answer at all ends in a **timeout** on the client side: wrong unit id or
address, wrong line settings, CRC error detected by the device (devices ignore damaged frames).

## 7. Values wider than 16 bits

Modbus defines 16-bit registers only. 32-bit integers and floats use **two consecutive
registers**, 64-bit values four. Each register is big-endian, but the **order of the registers**
is the device's choice: high word first (`ABCD`, the usual default), low word first (`CDAB`,
"word swap", very common), or with the bytes swapped inside each register (`BADC`, `DCBA`). The
device manual says which; if not, try the four orders and keep the one that gives a plausible
value (developer guide § 6).

## 8. Limits at a glance

| Item | Limit |
|------|-------|
| Coils / discrete inputs per read | 2000 |
| Registers per read (FC 03, 04, 23 read part) | 125 |
| Coils per write (FC 15) | 1968 |
| Registers per write (FC 16) | 123 |
| Registers written by FC 23 | 121 |
| Address range | 0–65535 per area |
| PDU size | 253 bytes |
| RTU frame size | 256 bytes |
| RTU unit ids | 1–247 (0 = broadcast) |
