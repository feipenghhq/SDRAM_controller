# SDRAM Controller

A high-performance SDRAM controller designed to interface with standard SDRAM chips.

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
.
├── doc                 # Documentation (datasheets, implementation)
│   ├── datasheets
├── fpga                # FPGA board-specific projects
│   ├── de2
│   └── de2-115
├── LICENSE
├── README.md
├── rtl                 # RTL source code for SDRAM controller
│   ├── chip            # Pre-defined controller top level for different SDRAM chip
│   └── sdram           # Various SDRAM controller implementation
├── scripts
│   ├── quartus         # Quartus build script
│   └── sdram_test      # Test script using Virtual JTAG
└── sim
    └── cocotb          # Cocotb simulation collateral
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

## SDRAM Bus Interface

The SDRAM controller use a custom bus interface. It is divided into 2 channels: request channel and response channel.

### Outstanding Transaction

With 2 channel architecture, the sdram support outstanding or pipelined transaction.

Parameter `MAX_OUTSTANDING` is added to indicate the maximum outstanding transaction it support.

If `MAX_OUTSTANDING` is not defined:
- The design does not support outstanding feature.
- Current transaction must complete before the next transaction is issued.

If `MAX_OUTSTANDING` is defined:
- the value to indicate the maximum outstanding transaction the system supports/requires.

### Interface

#### Request Channel

| Signal Name          | Direction | Description                                                |
| -------------------- | --------- | ---------------------------------------------------------- |
| `bus_req_read`       | Input     | Assert to initiate a read request                          |
| `bus_req_write`      | Input     | Assert to initiate a write request                         |
| `bus_req_addr`       | Input     | Byte address of the access                                 |
| `bus_req_burst`      | Input     | High if the request is a burst. Only asserts on first req. |
| `bus_req_burst_len`  | Input     | Burst length (number of beats).                            |
| `bus_req_wdata`      | Input     | Write data for the memory write                            |
| `bus_req_byteenable` | Input     | Byte enable mask for partial writes                        |
| `bus_req_ready`      | Output    | High when controller is ready                              |

Note on burst:
  - `bus_req_burst` only asserts on the first beat of the burst request.
  - `bus_req_burst_len` indicate the burst length and is valid when `bus_req_burst` is asserted.
    the burst length.
  - For read request, only one request is issued.
  - For write request, the subsequence request will provide the next write data and next address. The address needs to
    match with burst sequence

#### Response Channel
| Signal Name     | Direction | Description                 |
| --------------- | --------- | --------------------------- |
| `bus_rsp_valid` | Output    | Indicate read data is valid |
| `bus_rsp_rdata` | Output    | Read data                   |

## Implementation

### SDRAM Controller Variants

This repository includes multiple SDRAM controller variants with different features sets

The details of each design are documented in [sdram_implementation.md](doc/sdram_implementation.md).

Currently these are the planned features sets:

| Name               | Precharge Type   | Burst Support             | Status      |
| ------------------ | ---------------- | ------------------------- | ----------- |
| sdram_simple_ap.sv | auto precharge   | Single read/write only    | Done        |
| sdram_simple_mp.sv | manual precharge | Single read/write only    | In progress |
| sdram_burst_mp.sv  | manual precharge | Support burst transaction | TBD         |

The RTL source file are located in `rtl/sdram`.

### Pre-configured Top Modules for Target SDRAM Chip

The repository also provides predefined top-level modules tailored for specific SDRAM chips.
These modules come with parameters already configured to match the timing and organization of the target memory device.

The RTL source for pre-configured top modules are located in `rtl/chip`.

### Design Note

 See [sdram_implementation.md](doc/sdram_implementation.md) for detailed documentation on:
 - parameter and interface
 - state machine
 - timing diagrams

#### Important Architecture Note

1. **Custom bus interface**
    - Currently the design use a custom bus interface to interact with the sdram controller.
    - Future version may support industry standard interface such as **AHB-Lite** or **AXI**

2. **Single Clock domain**
    - The SDRAM controller runs in a single clock domain. The SDRAM clock is driven at the same frequency as the system clock.
    - Future version may support asynchronous clock for the bus interface and SDRAM control logic

3. **SDRAM CLK Phase Shift/Delay Consideration**
    - SDRAM signals (control, address, data) are expected to be latched by the SDRAM chip near the end of the clock cycle. This provides more robust timing.
    - However, it requires the SDRAM clock to be phase-shifted relative to the system clock to align correctly with the board layout and trace delay.
    - Example: in Terasic DE2/DE2-115 FPGA board, the phase delay between SDRAM_CLK and system clock is -3ns. ([Reference 2/3](#reference))

## FPGA Test

The SDRAM controller has been implemented and tested on Altera FPGA development boards: DE2 and DE2-115.

**Altera Virtual JTAG Host Interface**

A **VJTAG Host* is connected to the SDRAM controller in the FPGA. The host PC sends read/write command the SDRAM controller through the VJTAG Host.

> The Virtual JTAG Host is implemented in another repo: [virtual-jtag-host](https://github.com/feipenghhq/virtual-jtag-host). More details can be found there.

**Test Scripts**

Two tests are provided:
- **access_test**: Performs sequential memory access within a specified range.
- **random_test**: Performs randomized read/write tests to verify data integrity.
If you have the above FPGA board, you can test it in the board. Here are the commands

**How to run**

If you have a supported FPGA board (DE2 or DE2-115), you can run the SDRAM test as follows:

```sh
cd fpga/de2     # or cd fpga/de2-115
make pgm        # Build the FPGA image and program the FPGA board

cd scripts/sdram_test
./sdram_test.sh # Run SDRAM functional test via VJTAG
```

> Note:
> - DE2 (Cyclone II) requires Quartus 13.0sp1
> - DE2-115 (Cyclone IV) requires a newer version of Quartus



## Reference

1. [Micron MT48LC8M16A2 Datasheet](./doc/datasheets/Micron_Technology_128mb_x4x8x16_sdram-3473246.pdf)
2. [Using the SDRAM on Altera’s DE2 Board with Verilog Designs](https://people.ece.cornell.edu/land/courses/ece5760/DE2/tut_DE2_sdram_verilog.pdf)
3. [Using the SDRAM on Intel’s DE2-115 Board with Verilog Designs](https://ftp.intel.com/Public/Pub/fpgaup/pub/Teaching_Materials/current/Tutorials/Verilog/DE2-115/Using_the_SDRAM.pdf)