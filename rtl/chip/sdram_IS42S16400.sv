// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 07/19/2025
//
// -------------------------------------------------------------------
// SDRAM Controller for ISSI IS42S16400 SDR SDRAM
// - SDRAM Size: 64Mb
// - Data width: x16
// - Row width:  12
// - Col width:  8
// -------------------------------------------------------------------

module sdram_IS42S16400 #(
    parameter SPEED    = "-7",      // Speed level: -7/-8
    parameter CLK_FREQ = 100,       // (MHz) clock frequency
    parameter DW       = 16,        // x16
    parameter AW       = 23,        // SDRAM SIZE: 64Mb
    parameter RAW      = 12,        // Row addressing:    2K  A[11:0]
    parameter CAW      = 8          // Column addressing: 256 A[7:0]
) (
    input  logic            clk,
    input  logic            rst_n,
    // System Bus
    input  logic            bus_req_read,
    input  logic            bus_req_write,
    input  logic [AW-1:0]   bus_req_addr,
    input  logic            bus_req_burst,
    input  logic [2:0]      bus_req_burst_len,
    input  logic [DW-1:0]   bus_req_wdata,
    input  logic [1:0]      bus_req_byteenable,
    output logic            bus_req_ready,
    output logic            bus_rsp_valid,
    output logic [DW-1:0]   bus_rsp_rdata,
    // SDRAM Config
    input  logic [2:0]      cfg_burst_length,       // SDRAM Mode register: Burst Length
    input  logic            cfg_burst_type,         // SDRAM Mode register: Burst Type
    input  logic [2:0]      cfg_cas_latency,        // SDRAM Mode register: CAS Latency
    input  logic            cfg_burst_mode,         // SDRAM Mode register: Write Burst Mode
    // SDRAM interface
    output logic            sdram_cke,              // Clock Enable. CKE is high active.
    output logic            sdram_cs_n,             // Chip Select: CSn enables and disables command decoder.
    output logic            sdram_ras_n,            // Row Address Select.
    output logic            sdram_cas_n,            // Column Address Select.
    output logic            sdram_we_n,             // Write Enable.
    output logic [RAW-1:0]  sdram_addr,             // Address for row/column addressing.
    output logic [1:0]      sdram_ba,               // Bank Address. Fixed for 4 banks
    output logic [DW/8-1:0] sdram_dqm,              // Data Mask
    inout  wire  [DW-1:0]   sdram_dq                // Data Input/Output bus.
);

// ----------------------------------------------
// Parameter for SDRAM chip
// ----------------------------------------------

//                                 "-7"                   "-8"
localparam tRAS = (SPEED == "-7") ? 68 : (SPEED == "-8") ? 70 : 0; // (ns) ACTIVE-to-PRECHARGE command
localparam tRC  = (SPEED == "-7") ? 45 : (SPEED == "-8") ? 50 : 0; // (ns) ACTIVE-to-ACTIVE command period
localparam tRCD = (SPEED == "-7") ? 20 : (SPEED == "-8") ? 20 : 0; // (ns) ACTIVE-to-READ or WRITE delay
localparam tRFC = (SPEED == "-7") ? 68 : (SPEED == "-8") ? 70 : 0; // (ns) AUTO REFRESH period (Same as tRC in IS42S16400)
localparam tRP  = (SPEED == "-7") ? 20 : (SPEED == "-8") ? 20 : 0; // (ns) PRECHARGE command period
localparam tRRD = (SPEED == "-7") ? 15 : (SPEED == "-8") ? 20 : 0; // (ns) ACTIVE bank a to ACTIVE bank b command
localparam tREF = (SPEED == "-7") ? 64 : (SPEED == "-8") ? 64 : 0; // (ms) Refresh Period

// ----------------------------------------------
// Instantiate the general sdram controller
// ----------------------------------------------

sdram_controller #(
    .CLK_FREQ           (CLK_FREQ),
    .AW                 (AW),
    .DW                 (DW),
    .RAW                (RAW),
    .CAW                (CAW),
    .tRAS               (tRAS),
    .tRC                (tRC),
    .tRCD               (tRCD),
    .tRFC               (tRFC),
    .tRP                (tRP),
    .tRRD               (tRRD),
    .tREF               (tREF)
) u_sdram_controller (
    .*
);

endmodule
