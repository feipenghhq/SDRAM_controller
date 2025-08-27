# SDRAM Controller

This repo implement a high-performance SDRAM controller designed to interface with standard SDRAM chips.

## Features

- Fully synchronous design
- Compliant with JEDEC standard initialization sequence
- Auto-refresh management
- Read/Write support with burst transactions
- Configurable CAS latency
- Parameterizable address and data widths
- Modular architecture with multiple variants for different feature sets
- Support up to 133MHz (Tested in FPGA board)

## Repository Structure

```text

├── doc                 # Documentation (datasheets, state machine, implementation)
├── fpga                # FPGA projects
├── ip                  # IP used in the design
├── LICENSE
├── README.md
├── rtl
│   ├── fpga_examples   # FPGA example RTL source code
│   └── sdram           # SDRAM RTL source code
├── scripts
│   ├── quartus         # Quartus build script
│   └── sdram_test      # SDRAM test script using Virtual JTAG
└── sim
    └── cocotb          # Cocotb simulation
```

## SDRAM Interface and Timing

### SDRAM Interface

| Signal        | Direction | Description                                      |
| ------------- | --------- | ------------------------------------------------ |
| `sdram_cke`   | Output    | Clock Enable. Enables the SDRAM clock.           |
| `sdram_cs_n`  | Output    | Chip Select (Active Low).                        |
| `sdram_ras_n` | Output    | Row Address Strobe (Active Low).                 |
| `sdram_cas_n` | Output    | Column Address Strobe (Active Low).              |
| `sdram_we_n`  | Output    | Write Enable (Active Low).                       |
| `sdram_addr`  | Output    | Address bus. Provides row/column address.        |
| `sdram_ba`    | Output    | Bank Address. Selects the SDRAM bank.            |
| `sdram_dqm`   | Output    | Data Mask. Controls byte-wise access.            |
| `sdram_dq`    | Inout     | Bidirectional data bus. Carries read/write data. |

### SDRAM Timing

| Parameter | Unit | Description                                              |
| --------- | ---- | -------------------------------------------------------- |
| `tRAS`    | ns   | ACTIVE-to-PRECHARGE command time                         |
| `tRC`     | ns   | ACTIVE-to-ACTIVE command period                          |
| `tRCD`    | ns   | ACTIVE-to-READ or WRITE delay                            |
| `tRFC`    | ns   | AUTO REFRESH command period                              |
| `tRP`     | ns   | PRECHARGE command period                                 |
| `tRRD`    | ns   | Minimum delay between ACTIVE commands to different banks |
| `tWR`     | ns   | WRITE recovery time (WRITE completion to PRECHARGE)      |
| `tREF`    | ms   | Refresh period (time to refresh all rows)                |

The timing can usually be found in the SDRAM Datasheet

## Implementation

Check [sdram_impl.md](doc/sdram_impl.md) for detailed documentation on:
 - parameter and interface
 - state machine
 - timing diagrams

## FPGA Demo Program

The SDRAM controller is implemented and tested on DE2 and DE2-115 FPGA development boards.

### VJTAG to SDRAM

This FPGA demo program use **Altera Virtual JTAG Host Interface** to send request to the SDRAM controller in the FPGA

> The Virtual JTAG Host is implemented in another repo: [virtual-jtag-host](https://github.com/feipenghhq/virtual-jtag-host).

A test scripts is created to use VJTAG to test the SDRAM controller. It contains mainly 2 tests:
- **access test**: Performs sequential memory access within a specified range.
- **random test**: Performs randomized read/write tests to verify data integrity.

To run the test in the FPGA

```sh
cd fpga/de2     # or cd fpga/de2-115
make pgm        # Build the FPGA image and program the FPGA board

cd scripts/sdram_test
./sdram_test.sh # Run SDRAM functional test via VJTAG
```

## Reference

1. [Micron MT48LC8M16A2 Datasheet](./doc/datasheets/Micron_Technology_128mb_x4x8x16_sdram-3473246.pdf)
2. [Using the SDRAM on Altera’s DE2 Board with Verilog Designs](https://people.ece.cornell.edu/land/courses/ece5760/DE2/tut_DE2_sdram_verilog.pdf)
3. [Using the SDRAM on Intel’s DE2-115 Board with Verilog Designs](https://ftp.intel.com/Public/Pub/fpgaup/pub/Teaching_Materials/current/Tutorials/Verilog/DE2-115/Using_the_SDRAM.pdf)
