#!/usr/bin/env python3
"""Modbus TCP simulator for testing VNS Xojo Modbus without real hardware.

Two personalities:

  airh2o   (default) behaves like a Hitachi ATW-MBS-02 gateway (Yutaki line-up 2016 map):
           - FC03 and FC04 read the same table, unmapped addresses return 0xFFFF
           - FC06 writes the control block 1000-1033 and copies the value to its status mirror
           - every other function code answers exception 1 (illegal function)
           - the unit ID is ignored
           Initial values are the "Seen" column of docs/HITACHI_REGISTERS.md.

  generic  a plain Modbus server with 65536 coils, discrete inputs, holding and input
           registers (all zero), supporting FC 01, 02, 03, 04, 05, 06, 15, 16.
           Used to test the library's write functions. Exception 2 beyond the address space.

Usage:
  python3 tools/airh2o_simulator.py [--port 5020] [--mode airh2o|generic] [--drift] [--verbose]

Standard library only (Python 3.8+). Listens on 127.0.0.1 unless --host is given.
"""
import argparse
import asyncio
import os
import random
import re
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REGISTER_DOC = os.path.join(HERE, "..", "docs", "HITACHI_REGISTERS.md")

# Control register -> status mirror (line-up 2016 map). 1010 / 1021 (thermostat available)
# have no mirror.
CONTROL_TO_STATUS = {}
for c in range(1000, 1010):
    CONTROL_TO_STATUS[c] = c + 50                       # unit, circuit 1
CONTROL_TO_STATUS.update({1011: 1060, 1012: 1061})
for c in range(1013, 1021):
    CONTROL_TO_STATUS[c] = c + 51                       # circuit 2
CONTROL_TO_STATUS.update({1022: 1072, 1023: 1073,
                          1024: 1076, 1025: 1077, 1026: 1078, 1027: 1079,
                          1028: 1081, 1029: 1082, 1030: 1084, 1031: 1085,
                          1032: 1086, 1033: 1087})

# Gateway self-configuration block (author's unit, see HITACHI_REGISTERS.md)
GATEWAY_BLOCK = {0: 0x0F06, 1: 0x0067, 2: 0x0002,
                 20: 192, 21: 168, 22: 2, 23: 162, 24: 502,
                 25: 255, 26: 255, 27: 255, 28: 0,
                 29: 192, 30: 168, 31: 2, 32: 1}
for slot in range(7):
    GATEWAY_BLOCK[50 + slot * 2] = 0xC0A8               # 192.168
    GATEWAY_BLOCK[51 + slot * 2] = 0x026C               # 2.108

ROW = re.compile(r"^\|\s*\*\*(\d+)\*\*\s*\|\s*\d+\s*\|\s*(R/W|R)\s*\|.*\|\s*([^|]*)\|\s*$")
SEEN = re.compile(r"^\s*(0x[0-9A-Fa-f]+|-?\d+)")


def load_airh2o_table():
    """Return {address: uint16} from the Seen column of the register doc."""
    table = dict(GATEWAY_BLOCK)
    with open(REGISTER_DOC, encoding="utf-8") as f:
        for line in f:
            m = ROW.match(line)
            if not m:
                continue
            seen = SEEN.match(m.group(3))
            if not seen:
                continue                                # "—" = not implemented -> 0xFFFF
            value = int(seen.group(1), 0)
            table[int(m.group(1))] = value & 0xFFFF
    return table


class Device:
    def __init__(self, mode, verbose):
        self.mode = mode
        self.verbose = verbose
        if mode == "airh2o":
            self.registers = load_airh2o_table()
        else:
            self.coils = bytearray(65536)
            self.discretes = bytearray(65536)
            self.holding = [0] * 65536
            self.inputs = [0] * 65536

    # ---------------------------------------------------------------- airh2o
    def airh2o(self, fc, pdu):
        if fc in (3, 4):
            addr, count = struct.unpack(">HH", pdu[1:5])
            if not 1 <= count <= 125:
                return exception(fc, 3)
            values = [self.registers.get(a, 0xFFFF) for a in range(addr, addr + count)]
            return struct.pack(">BB", fc, count * 2) + struct.pack(">%dH" % count, *values)
        if fc == 6:
            addr, value = struct.unpack(">HH", pdu[1:5])
            if not 1000 <= addr <= 1033:
                return exception(fc, 2)
            self.registers[addr] = value
            if addr in CONTROL_TO_STATUS:
                self.registers[CONTROL_TO_STATUS[addr]] = value
            if self.verbose:
                print("  write %d = %d" % (addr, value))
            return pdu[:5]                              # echo
        return exception(fc, 1)

    def drift(self):
        """Move a few temperatures a little, so a polling client sees changes."""
        for addr in (1080, 1091, 1092, 1093, 1200):
            v = to_signed(self.registers.get(addr, 0))
            if v in (-127, -67):
                continue
            v += random.choice((-1, 0, 0, 1))
            self.registers[addr] = v & 0xFFFF

    # ---------------------------------------------------------------- generic
    def generic(self, fc, pdu):
        try:
            if fc in (1, 2):
                addr, count = struct.unpack(">HH", pdu[1:5])
                if not 1 <= count <= 2000:
                    return exception(fc, 3)
                if addr + count > 65536:
                    return exception(fc, 2)
                bits = (self.coils if fc == 1 else self.discretes)[addr:addr + count]
                packed = pack_bits(bits)
                return struct.pack(">BB", fc, len(packed)) + packed
            if fc in (3, 4):
                addr, count = struct.unpack(">HH", pdu[1:5])
                if not 1 <= count <= 125:
                    return exception(fc, 3)
                if addr + count > 65536:
                    return exception(fc, 2)
                src = self.holding if fc == 3 else self.inputs
                return struct.pack(">BB", fc, count * 2) + struct.pack(">%dH" % count, *src[addr:addr + count])
            if fc == 5:
                addr, value = struct.unpack(">HH", pdu[1:5])
                if value not in (0x0000, 0xFF00):
                    return exception(fc, 3)
                self.coils[addr] = 1 if value == 0xFF00 else 0
                return pdu[:5]
            if fc == 6:
                addr, value = struct.unpack(">HH", pdu[1:5])
                self.holding[addr] = value
                return pdu[:5]
            if fc == 15:
                addr, count, nbytes = struct.unpack(">HHB", pdu[1:6])
                if not 1 <= count <= 1968 or nbytes != (count + 7) // 8:
                    return exception(fc, 3)
                if addr + count > 65536:
                    return exception(fc, 2)
                data = pdu[6:6 + nbytes]
                for i in range(count):
                    self.coils[addr + i] = (data[i // 8] >> (i % 8)) & 1
                return pdu[:5]
            if fc == 16:
                addr, count, nbytes = struct.unpack(">HHB", pdu[1:6])
                if not 1 <= count <= 123 or nbytes != count * 2:
                    return exception(fc, 3)
                if addr + count > 65536:
                    return exception(fc, 2)
                self.holding[addr:addr + count] = struct.unpack(">%dH" % count, pdu[6:6 + nbytes])
                return pdu[:5]
        except struct.error:
            return exception(fc, 3)
        return exception(fc, 1)

    def handle(self, pdu):
        fc = pdu[0]
        return self.airh2o(fc, pdu) if self.mode == "airh2o" else self.generic(fc, pdu)


def exception(fc, code):
    return struct.pack(">BB", fc | 0x80, code)


def pack_bits(bits):
    out = bytearray((len(bits) + 7) // 8)
    for i, b in enumerate(bits):
        if b:
            out[i // 8] |= 1 << (i % 8)
    return bytes(out)


def to_signed(v):
    return v - 0x10000 if v >= 0x8000 else v


async def serve_client(device, reader, writer):
    peer = writer.get_extra_info("peername")
    if device.verbose:
        print("connect", peer)
    try:
        while True:
            header = await reader.readexactly(7)
            tid, pid, length, unit = struct.unpack(">HHHB", header)
            pdu = await reader.readexactly(length - 1)
            reply = device.handle(pdu)
            if device.verbose:
                print("  tid=%d unit=%d fc=%d -> %s" % (tid, unit, pdu[0], reply.hex()))
            writer.write(struct.pack(">HHHB", tid, pid, len(reply) + 1, unit) + reply)
            await writer.drain()
    except (asyncio.IncompleteReadError, ConnectionResetError):
        pass
    finally:
        writer.close()
        if device.verbose:
            print("disconnect", peer)


async def drift_loop(device):
    while True:
        await asyncio.sleep(5)
        device.drift()


async def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=5020)
    ap.add_argument("--mode", choices=("airh2o", "generic"), default="airh2o")
    ap.add_argument("--drift", action="store_true", help="airh2o: vary temperatures every 5 s")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()
    sys.stdout.reconfigure(line_buffering=True)

    device = Device(args.mode, args.verbose)
    server = await asyncio.start_server(lambda r, w: serve_client(device, r, w), args.host, args.port)
    print("Modbus TCP simulator (%s) listening on %s:%d" % (args.mode, args.host, args.port))
    if args.mode == "airh2o":
        print("  %d registers loaded from %s" % (len(device.registers), os.path.relpath(REGISTER_DOC)))
        if args.drift:
            asyncio.ensure_future(drift_loop(device))
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
