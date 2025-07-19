# SDRAM Controller

A high-performance SDRAM controller designed to interface with standard SDRAM chips.

## Features

- Compatible with [insert SDRAM chip model, e.g., MT48LC4M16A2]
- Fully synchronous design
- Supports:
  - Initialization sequence per JEDEC standard
  - Auto-refresh management
  - Read/Write with burst support
  - CAS latency configuration
- Parameterizable address and data widths
- Designed for FPGA implementation

## Implementation

### Parameters

#### System Parameters

| Name        | Description   |
| ----------- | ------------- |
| ADDR_WIDTH  | Address Width |
| DATA_WIDTH  | Data Width    |

#### SDRAM Parameters

### Interfaces

#### Clock and Reset

| Signal Name | Direction | Width | Description              |
| ----------- | --------- | ----- | ------------------------ |
| `clk`       | Input     | 1     | System clock.            |
| `rst_n`     | Input     | 1     | Active-low reset signal. |

#### Bus Interface

To provide high performance, We use AHB-Lite as the main bus interface to interact with the SDRAM Controller

##### Host Signals

| Signal Name   | Direction | Width | Description                                                                             |
| ------------- | --------- | ----- | --------------------------------------------------------------------------------------- |
| `haddr`       | Input     | AW    | System address bus. The width should match with the size of the SDRAM.                  |
| `hburst`      | Input     | 3     | The burst type indicates if the transfer is a single transfer or forms part of a burst. |
| `hmasterlock` | Input     | 1     | When HIGH, this signal indicates that the current transfer is part of a locked sequence |
| `hprot`       | Input     | 4     | Protection control signals. **Not Used**.                                               |
| `hsize`       | Input     | 3     | Transfer size: byte, halfword, word.                                                    |
| `htrans`      | Input     | 2     | Transfer type: IDLE, BUSY, NONSEQ, SEQ.                                                 |
| `hwdata`      | Input     | DW    | Write data bus.                                                                         |
| `hwrite`      | Input     | 1     | Transfer direction: 1 = write, 0 = read.                                                |

##### Device Signals

| Signal Name | Direction | Width | Description                                                                       |
| ----------- | --------- | ----- | --------------------------------------------------------------------------------- |
| `hrdata`    | Output    | DW    | Read data bus.                                                                    |
| `hreadyout` | Output    | 1     | When HIGH, the HREADYOUT signal indicates that a transfer has finished on the bus |
| `hresp`     | Output    | 1     | Transfer response: OKAY, ERROR, etc.                                              |



#### SDRAM Interface

| Name            | Type  | Width | Function                                                                                                                                 |
| --------------- | ----- | ----- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| sdram_clk       | Input | 1     | Master Clock. Other input signals are clock at CLK rising edge.                                                                          |
| sdram_cke       | Input | 1     | Clock Enable. CKE is high active.                                                                                                        |
| sdram_cs_n      | Input | 1     | Chip Select: CSn enable and disables command decoder.                                                                                    |
| sdram_ras_n     | Input | 1     | Row Address Select.                                                                                                                      |
| sdram_cas_n     | Input | 1     | Column Address Select.                                                                                                                   |
| sdram_we_n      | Input | 1     | Write Enable.                                                                                                                            |
| sdram_addr      | Input | AW    | Address Inputs. Provide the row address for `ACTIVT` commands and the column address and `AUTO PRECHARGE` bit for `READ/WRITE` commands. |
| sdram_ba0/ba1   | Input | 1     | Bank Address Inputs. BA0 and BA1 define to which bank a command is applied.                                                              |
| sdram_dqm       | Input | 1     |                                                                                                                                          |
| sdram_udqm/ldqm | Input | 1     |                                                                                                                                          |
| sdram_dq        | Input | DW    | Data Input/Output bus                                                                                                                    |

### State Diagram

## Reference

1. [AHB-Lite Specification](http://eecs.umich.edu/courses/eecs373/readings/ARM_IHI0033A_AMBA_AHB-Lite_SPEC.pdf)