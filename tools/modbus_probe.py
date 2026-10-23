#!/usr/bin/env python3
"""Read-only Modbus TCP probe: dumps registers or bits from a device.

It only sends read requests (FC 01, 02, 03, 04) and can never change a device.

Usage:
  python3 tools/modbus_probe.py HOST [--port 502] [--unit 1] [--fc 3] ADDRESS [COUNT]

Example:
  python3 tools/modbus_probe.py 192.168.2.162 1050 49
"""
import argparse
import socket
import struct

EXCEPTIONS = {1: "illegal function", 2: "illegal data address", 3: "illegal data value",
              4: "server device failure", 6: "server device busy",
              10: "gateway path unavailable", 11: "gateway target failed to respond"}


def read(host, port, unit, fc, address, count, timeout):
    with socket.create_connection((host, port), timeout=timeout) as s:
        s.sendall(struct.pack(">HHHBBHH", 1, 0, 6, unit, fc, address, count))
        header = recv_exact(s, 7)
        tid, pid, length, _ = struct.unpack(">HHHB", header)
        pdu = recv_exact(s, length - 1)
    if pdu[0] & 0x80:
        code = pdu[1]
        raise RuntimeError("exception %d (%s)" % (code, EXCEPTIONS.get(code, "unknown")))
    data = pdu[2:2 + pdu[1]]
    if fc in (1, 2):
        return [(data[i // 8] >> (i % 8)) & 1 for i in range(count)]
    return list(struct.unpack(">%dH" % (len(data) // 2), data))


def recv_exact(s, n):
    buf = b""
    while len(buf) < n:
        chunk = s.recv(n - len(buf))
        if not chunk:
            raise RuntimeError("connection closed")
        buf += chunk
    return buf


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("host")
    ap.add_argument("address", type=int, help="0-based protocol address")
    ap.add_argument("count", type=int, nargs="?", default=1)
    ap.add_argument("--port", type=int, default=502)
    ap.add_argument("--unit", type=int, default=1)
    ap.add_argument("--fc", type=int, choices=(1, 2, 3, 4), default=3)
    ap.add_argument("--timeout", type=float, default=3.0)
    args = ap.parse_args()

    try:
        values = read(args.host, args.port, args.unit, args.fc, args.address, args.count, args.timeout)
    except (OSError, RuntimeError) as err:
        raise SystemExit("error: %s" % err)
    for i, v in enumerate(values):
        if args.fc in (1, 2):
            print("%6d  %d" % (args.address + i, v))
        else:
            signed = v - 0x10000 if v >= 0x8000 else v
            print("%6d  %5d  %6d  0x%04X" % (args.address + i, v, signed, v))


if __name__ == "__main__":
    main()
