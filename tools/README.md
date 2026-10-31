# Tools

Python 3.8+ helpers, standard library only. They are not part of the Xojo library.

| Script | Purpose |
|--------|---------|
| `airh2o_simulator.py` | Modbus TCP server that behaves like the Hitachi ATW-MBS-02 gateway (`--mode airh2o`, default) or a plain Modbus device supporting FC 01–06, 15, 16, 23 (`--mode generic`). Lets you run the example app and test the library without hardware. |
| `modbus_probe.py` | Read-only dump of registers or bits from any Modbus TCP device. It only sends read requests. |

```sh
# simulated heat pump on port 5020, temperatures drifting every 5 s
python3 tools/airh2o_simulator.py --drift --verbose

# generic device for testing writes
python3 tools/airh2o_simulator.py --mode generic --port 5021

# read the status block of the simulator (or of a real device on port 502)
python3 tools/modbus_probe.py 127.0.0.1 --port 5020 1050 49
```

In the example app, set the address to `127.0.0.1` and the port to `5020` to use the simulator.
The airH2O simulator takes its initial values from the *Seen* column of
[`docs/HITACHI_REGISTERS.md`](../docs/HITACHI_REGISTERS.md); FC06 writes to the control block
(1000–1033) are copied to their status mirror, as on the real gateway.
