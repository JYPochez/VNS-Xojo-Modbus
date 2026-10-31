# Console live test

A console project that uses the library files in place (`../../Modbus`) and checks them against
the generic simulator: every function code (01–06, 08, 15, 16, 17, 22, 23, 43), a negative register value and a
word-swapped `Float32`, after the offline `ModbusSelfTest`. It is also the reference for using
the library without a window (subclass + `App.DoEvents` loop, see the developer guide § 11).

```sh
python3 tools/airh2o_simulator.py --mode generic --port 5021   # from the repository root
```

Open `ModbusLiveTest.xojo_project` in Xojo and run it (optional argument: another port).
Exit code 0 = all passed, 1 = a check failed, 2 = no answer from the simulator.
