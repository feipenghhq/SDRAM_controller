// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 07/30/2025
//
// -------------------------------------------------------------------
// SDRAM controller top level
// -------------------------------------------------------------------

`default_nettype none

module sdram_controller #(
    parameter CLK_FREQ  = 100,      // (MHz) clock frequency
    parameter AW        = 24,       // Bus Address width. Should match with SDRAM size
    parameter DW        = 16,       // Bus Data width
    // SDRAM Size
    parameter RAW       = 12,       // SDRAM Address width
    parameter CAW       = 9,        // SDRAM Column address width
    // SDRAM timing parameter
    parameter tRAS      = 42,       // (ns) ACTIVE-to-PRECHARGE command
    parameter tRC       = 60,       // (ns) ACTIVE-to-ACTIVE command period
    parameter tRCD      = 18,       // (ns) ACTIVE-to-READ or WRITE delay
    parameter tRFC      = 60,       // (ns) AUTO REFRESH period
    parameter tRP       = 18,       // (ns) PRECHARGE command period
    parameter tRRD      = 20,       // (ns) ACTIVE bank a to ACTIVE bank b command
    parameter tWR       = 20,       // (ns) WRITE recovery time (WRITE completion to PRECHARGE period)
    parameter tREF      = 64        // (ms) Refresh Period
) (
    input  logic            clk,
    input  logic            rst_n,

    // System Bus
    input  logic            bus_req_read,           // read request
    input  logic            bus_req_write,          // write request
    input  logic [AW-1:0]   bus_req_addr,           // address
    input  logic            bus_req_burst,          // indicate burst transfer
    input  logic [2:0]      bus_req_burst_len,      // Burst length
    input  logic [DW-1:0]   bus_req_wdata,          // write data
    input  logic [DW/8-1:0] bus_req_byteenable,     // byte enable
    output logic            bus_req_ready,          // ready

    output logic            bus_rsp_valid,          // read data valid
    output logic [DW-1:0]   bus_rsp_rdata,          // read data

    // SDRAM Config
    input  logic [2:0]      cfg_burst_length,       // SDRAM Mode register: Burst Length
    input  logic            cfg_burst_type,         // SDRAM Mode register: Burst Type
    input  logic [2:0]      cfg_cas_latency,        // SDRAM Mode register: CAS Latency
    input  logic            cfg_burst_mode,         // SDRAM Mode register: Write Burst Mode

    // SDRAM interface
    output logic            sdram_cke,              // Clock Enable.
    output logic            sdram_cs_n,             // Chip Select.
    output logic            sdram_ras_n,            // Row Address Select.
    output logic            sdram_cas_n,            // Column Address Select.
    output logic            sdram_we_n,             // Write Enable.
    output logic [RAW-1:0]  sdram_addr,             // Address.
    output logic [1:0]      sdram_ba,               // Bank.
    output logic [DW/8-1:0] sdram_dqm,              // Data Mask
    inout  wire  [DW-1:0]   sdram_dq                // Data Input/Output bus.
);

sdram_ctrl_auto_precharge #(
     .CLK_FREQ (CLK_FREQ)
    ,.AW       (AW)
    ,.DW       (DW)
    ,.RAW      (RAW)
    ,.CAW      (CAW)
    ,.tRAS     (tRAS)
    ,.tRC      (tRC)
    ,.tRCD     (tRCD)
    ,.tREF     (tREF)
    ,.tRFC     (tRFC)
    ,.tRP      (tRP)
    ,.tRRD     (tRRD)
) u_sdram_ctrl (
    .*
);

endmodule
