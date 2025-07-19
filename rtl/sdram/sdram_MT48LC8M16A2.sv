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
// -------------------------------------------------------------------

module sdram_MT48LC8M16A2 #(
    parameter DW = 16,          // x16
    parameter AW = 24,          // SDRAM SIZE: 128Mb
    parameter CLK_FREQ = 100,   // (MHz) clock frequency
    parameter RAW = 12,         // Row addressing:    4K  A[11:0]
    parameter CAW = 9           // Column addressing: 512 A[8:0]
) (
    input  logic            clk,
    input  logic            rst_n,
    // AHB-Lite Bus
    input  logic [AW-1:0]   haddr,
    input  logic [2:0]      hburst,
    input  logic            hmasterlock,
    input  logic [3:0]      hprot,
    input  logic [2:0]      hsize,
    input  logic [1:0]      htrans,
    input  logic [DW-1:0]   hwdata,
    input  logic            hwrite,
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
    inout  logic [DW-1:0]   sdram_dq                // Data Input/Output bus.
);

// ----------------------------------------------
// Parameter for SDRAM chip
// ----------------------------------------------

// sdram timing parameter
localparam tRAS = 42;        // (ns) ACTIVE-to-PRECHARGE command
localparam tRC  = 60;        // (ns) ACTIVE-to-ACTIVE command period
localparam tRCD = 18;        // (ns) ACTIVE-to-READ or WRITE delay
localparam tREF = 64;        // (ms) Refresh Period
localparam tRFC = 60;        // (ns) AUTO REFRESH period
localparam tRP  = 18;        // (ns) PRECHARGE command period
localparam tRRD = 20;        // (ns) ACTIVE bank a to ACTIVE bank b command
localparam cMRD = 2;         // (cycle) LOAD MODE REGISTER command to ACTIVE or REFRESH command

// sdram initialization sequence
localparam INIT_TIME = 100;  // (us) initialization NOP time

// ----------------------------------------------
// Instantiate the general sdram controller
// ----------------------------------------------

sdram_controller #(
    .AW                 (AW),
    .DW                 (DW),
    .CLK_FREQ           (CLK_FREQ),
    .RAW                (RAW),
    .CAW                (CAW),
    .tRAS               (tRAS),
    .tRC                (tRC),
    .tRCD               (tRCD),
    .tREF               (tREF),
    .tRFC               (tRFC),
    .tRP                (tRP),
    .tRRD               (tRRD),
    .cMRD               (cMRD),
    .INIT_TIME          (INIT_TIME)
) u_sdram_controller (
    .clk                (clk),
    .rst_n              (rst_n),
    .haddr              (haddr),
    .hburst             (hburst),
    .hmasterlock        (hmasterlock),
    .hprot              (hprot),
    .hsize              (hsize),
    .htrans             (htrans),
    .hwdata             (hwdata),
    .hwrite             (hwrite),
    .cfg_burst_length   (cfg_burst_length),
    .cfg_burst_type     (cfg_burst_type),
    .cfg_cas_latency    (cfg_cas_latency),
    .cfg_burst_mode     (cfg_burst_mode),
    .sdram_cke          (sdram_cke),
    .sdram_cs_n         (sdram_cs_n),
    .sdram_ras_n        (sdram_ras_n),
    .sdram_cas_n        (sdram_cas_n),
    .sdram_we_n         (sdram_we_n),
    .sdram_addr         (sdram_addr),
    .sdram_ba           (sdram_ba),
    .sdram_dqm          (sdram_dqm),
    .sdram_dq           (sdram_dq)
);

endmodule
