// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 08/29/2025
//
// -------------------------------------------------------------------
// SDRAM Controller
// -------------------------------------------------------------------

`include "sdram_inc.svh"

module sdram_controller #(
    parameter CLK_FREQ  = 100,      // (MHz) clock frequency
    parameter AW        = 24,       // Bus Address width. Should match with SDRAM size
    parameter DW        = 16,       // Bus Data width
    // SDRAM Size
    parameter RAW       = 12,       // SDRAM Address width
    parameter CAW       = 9,        // SDRAM Column address width
    // SDRAM timing parameter
    parameter tRAS      = 37,       // (ns) ACTIVE-to-PRECHARGE command
    parameter tRC       = 60,       // (ns) ACTIVE-to-ACTIVE command period
    parameter tRCD      = 15,       // (ns) ACTIVE-to-READ or WRITE delay
    parameter tRFC      = 66,       // (ns) AUTO REFRESH period
    parameter tRP       = 15,       // (ns) PRECHARGE command period
    parameter tRRD      = 14,       // (ns) ACTIVE bank a to ACTIVE bank b command
    parameter tWR       = 15,       // (ns) WRITE recovery time (WRITE completion to PRECHARGE period)
    parameter tREF      = 64        // (ms) Refresh Period
) (
    input  logic            clk,
    input  logic            rst_n,

    // System Bus
    input  logic            req_valid,              // request valid
    input  logic            req_write,              // 0: read request. 1: write request
    input  logic [AW-1:0]   req_addr,               // address
    input  logic [DW-1:0]   req_wdata,              // write data
    input  logic [DW/8-1:0] req_byteenable,         // byte enable
    output logic            req_ready,              // ready

    output logic            rsp_early_valid,        // one cycle before read data valid
    output logic            rsp_valid,              // read data valid
    output logic [DW-1:0]   rsp_rdata,              // read data

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

logic            ctrl_valid;
logic [3:0]      ctrl_cmd;
logic [RAW-1:0]  ctrl_addr;
logic [DW-1:0]   ctrl_data;
logic [1:0]      ctrl_ba;
logic [DW/8-1:0] ctrl_dqm;

logic            init_valid;
logic [3:0]      init_cmd;
logic [RAW-1:0]  init_addr;
logic            init_done;

logic            cmd_valid;
logic [3:0]      cmd_type;
logic [RAW-1:0]  cmd_addr;
logic [DW-1:0]   cmd_data;
logic [1:0]      cmd_ba;
logic [DW/8-1:0] cmd_dqm;
logic            cmd_wip;
logic            cmd_done;
logic            cmd_early_done;

// mux select between init command and ctrl command
assign cmd_valid = init_done ? ctrl_valid : init_valid;
assign cmd_type  = init_done ? ctrl_cmd   : init_cmd;
assign cmd_addr  = init_done ? ctrl_addr  : init_addr;
assign cmd_data  = ctrl_data;
assign cmd_ba    = ctrl_ba;
assign cmd_dqm   = ctrl_dqm;

sdram_init #(
    .CLK_FREQ (CLK_FREQ),
    .AW       (RAW))
u_sdram_init
(
    .clk              (clk),
    .rst_n            (rst_n),
    .cfg_burst_length (cfg_burst_length),
    .cfg_burst_type   (cfg_burst_type),
    .cfg_cas_latency  (cfg_cas_latency),
    .cfg_burst_mode   (cfg_burst_mode),
    .init_valid       (init_valid),
    .init_cmd         (init_cmd),
    .init_addr        (init_addr),
    .init_done        (init_done),
    .cmd_wip          (cmd_wip),
    .cmd_done         (cmd_done)
);

sdram_ctrl #(
    .CLK_FREQ (CLK_FREQ),
    .AW   (AW),
    .DW   (DW),
    .RAW  (RAW),
    .CAW  (CAW),
    .tWR  (tWR),
    .tREF (tREF))
u_sdram_ctrl (
    .clk                (clk),
    .rst_n              (rst_n),
    .init_done          (init_done),
    .cmd_valid          (ctrl_valid),
    .cmd_type           (ctrl_cmd),
    .cmd_addr           (ctrl_addr),
    .cmd_data           (ctrl_data),
    .cmd_ba             (ctrl_ba),
    .cmd_dqm            (ctrl_dqm),
    .cmd_done           (cmd_done),
    .cmd_early_done     (cmd_early_done),
    .cmd_wip            (cmd_wip),
    .cfg_burst_length   (cfg_burst_length),
    .cfg_burst_type     (cfg_burst_type),
    .cfg_cas_latency    (cfg_cas_latency),
    .cfg_burst_mode     (cfg_burst_mode),
    .sdram_dq_in        (sdram_dq),
    .req_valid          (req_valid),
    .req_write          (req_write),
    .req_addr           (req_addr),
    .req_wdata          (req_wdata),
    .req_byteenable     (req_byteenable),
    .req_ready          (req_ready),
    .rsp_early_valid    (rsp_early_valid),
    .rsp_valid          (rsp_valid),
    .rsp_rdata          (rsp_rdata)
);

sdram_cmd #(
    .CLK_FREQ (CLK_FREQ),
    .RAW      (RAW),
    .DW       (DW),
    .tRAS     (tRAS),
    .tRC      (tRC),
    .tRCD     (tRCD),
    .tRFC     (tRFC),
    .tRP      (tRP),
    .tRRD     (tRRD),
    .tWR      (tWR),
    .tREF     (tREF)
)
u_sdram_cmd(
    .clk             (clk),
    .rst_n           (rst_n),
    .cmd_valid       (cmd_valid),
    .cmd_type        (cmd_type),
    .cmd_addr        (cmd_addr),
    .cmd_data        (cmd_data),
    .cmd_ba          (cmd_ba),
    .cmd_dqm         (cmd_dqm),
    .cmd_wip         (cmd_wip),
    .cmd_done        (cmd_done),
    .cmd_early_done  (cmd_early_done),
    .cfg_cas_latency (cfg_cas_latency),
    .sdram_cke       (sdram_cke),
    .sdram_cs_n      (sdram_cs_n),
    .sdram_ras_n     (sdram_ras_n),
    .sdram_cas_n     (sdram_cas_n),
    .sdram_we_n      (sdram_we_n),
    .sdram_addr      (sdram_addr),
    .sdram_ba        (sdram_ba),
    .sdram_dqm       (sdram_dqm),
    .sdram_dq        (sdram_dq)
);

endmodule
