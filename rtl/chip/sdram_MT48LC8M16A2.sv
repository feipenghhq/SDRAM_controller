// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 07/18/2025
//
// -------------------------------------------------------------------
// SDRAM Controller for Micro MT48LC8M16A2 SDR SDRAM
// - SDRAM Size: 128Mb
// - Data width: x16
// - Row width:  12
// - Col width:  9
// -------------------------------------------------------------------

module sdram_MT48LC8M16A2 #(
    parameter SPEED    = "-7E",     // Speed level: -6A/-7E/-75
    parameter CLK_FREQ = 133,      // (MHz) clock frequency
    parameter DW       = 16,       // x16
    parameter AW       = 24,       // SDRAM SIZE: 128Mb
    parameter RAW      = 12,       // Row addressing:    4K  A[11:0]
    parameter CAW      = 9         // Column addressing: 512 A[8:0]
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

//                                 "-6A"                   "-7E"                   "-75"
localparam tRAS = (SPEED == "-6A") ? 42 : (SPEED == "-7E") ? 37 : (SPEED == "-75") ? 44 : 0; // (ns) ACTIVE-to-PRECHARGE command
localparam tRC  = (SPEED == "-6A") ? 60 : (SPEED == "-7E") ? 60 : (SPEED == "-75") ? 66 : 0; // (ns) ACTIVE-to-ACTIVE command period
localparam tRCD = (SPEED == "-6A") ? 18 : (SPEED == "-7E") ? 15 : (SPEED == "-75") ? 20 : 0; // (ns) ACTIVE-to-READ or WRITE delay
localparam tRFC = (SPEED == "-6A") ? 60 : (SPEED == "-7E") ? 66 : (SPEED == "-75") ? 66 : 0; // (ns) AUTO REFRESH period
localparam tRP  = (SPEED == "-6A") ? 18 : (SPEED == "-7E") ? 15 : (SPEED == "-75") ? 15 : 0; // (ns) PRECHARGE command period
localparam tRRD = (SPEED == "-6A") ? 12 : (SPEED == "-7E") ? 14 : (SPEED == "-75") ? 15 : 0; // (ns) ACTIVE bank a to ACTIVE bank b command
localparam tREF = (SPEED == "-6A") ? 64 : (SPEED == "-7E") ? 64 : (SPEED == "-75") ? 64 : 0; // (ms) Refresh Period


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
    .tREF               (tREF),
    .tRFC               (tRFC),
    .tRP                (tRP),
    .tRRD               (tRRD)
) u_sdram_controller (
    .*
);

endmodule
