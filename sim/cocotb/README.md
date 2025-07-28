# Cocotb Test

## Structure

```text
.
├── model                   # SDRAM Simulation Model
│   └── MT48LC8M16A2.v
├── README.md
├── tb                      # SystemVerilog testbench file
│   └── tb_top.sv
└── tests                   # Cocotb test
    ├── bus.py              # Bus driver
    ├── env.py              # Test environment
    ├── Makefile
    ├── test_*.py           # Tests
    └── wave.gtkw

```

## Test Case

- `test_basic.py`: Single write and read test
- `test_random_rw.py`: Random write and read test
- `test_regression.py`: Regression test

## Test Commands


```bash
# general command
make clean && make MODULE=<test> FREQ=<clock freq>

# Run basic test with different clock frequency
make clean && make FREQ=50
make clean && make FREQ=100
make clean && make FREQ=133

# Run random_rw test with different clock frequency
make clean && make MODULE=test_random_rw FREQ=50
make clean && make MODULE=test_random_rw FREQ=100
make clean && make MODULE=test_random_rw FREQ=133

# Run manual_precharge test with different clock frequency
make clean && make MODULE=test_manual_precharge FREQ=50
make clean && make MODULE=test_manual_precharge FREQ=100
make clean && make MODULE=test_manual_precharge FREQ=133

# Run regression with different clock frequency
make clean && make MODULE=test_regression FREQ=50
make clean && make MODULE=test_regression FREQ=100
make clean && make MODULE=test_regression FREQ=133
```



Note: `make clean` is required in each command to clear previous compilation result