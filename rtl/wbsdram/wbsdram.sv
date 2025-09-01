// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 08/06/2025
//
// -------------------------------------------------------------------
// SDRAM controller with wishbone interface
//   - Wishbone B4 pipeline protocol
// -------------------------------------------------------------------

`default_nettype none

module wbsdram #(
    parameter CLK_FREQ  = 133,   // (MHz) clock frequency
    parameter AW        = 24,        // Bus Address width.
    parameter DW        = 16,        // Bus Data width
    // SDRAM Size
    parameter RAW       = 12,        // SDRAM Address width
    parameter CAW       = 9,         // SDRAM Column address width
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

    // Wishbone bus
    input  logic [DW-1:0]   wb_dat_i,
    output logic [DW-1:0]   wb_dat_o,
    input  logic            wb_cyc_i,
    input  logic            wb_stb_i,
    input  logic            wb_we_i,
    input  logic [AW-1:0]   wb_adr_i,
    input  logic [DW/8-1:0] wb_sel_i,
    output logic            wb_ack_o,
    output logic            wb_stall_o,

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

    logic            wb_valid;

    logic            req_valid;
    logic            req_write;
    logic [AW-1:0]   req_addr;
    logic [DW-1:0]   req_wdata;
    logic [DW/8-1:0] req_byteenable;
    logic            req_ready;
    logic            rsp_early_valid;
    logic            rsp_valid;
    logic [DW-1:0]   rsp_rdata;

    logic            req_is_write;
    logic            req_is_read;

    logic            req_sent;      // request is sent, waiting for completion

    assign wb_valid = wb_cyc_i & wb_stb_i;

    // Wishbone to genetic bus
    assign req_valid = wb_valid & ~req_sent;
    assign req_write = wb_we_i;
    assign req_addr  = wb_adr_i;
    assign req_wdata = wb_dat_i;
    assign req_byteenable = wb_sel_i;

    assign req_is_write = wb_valid & req_write;
    assign req_is_read  = wb_valid & ~req_write;

    assign wb_stall_o = (req_is_write & ~req_ready) | (req_is_read & ~rsp_early_valid);
    assign wb_dat_o   = rsp_rdata;

    always @(posedge clk) begin
        if (!rst_n) begin
            wb_ack_o <= 1'b0;
            req_sent <= 1'b0;
        end
        else begin
            wb_ack_o <= wb_valid & ~wb_stall_o;
            if (req_valid && req_ready) req_sent <= 1'b1;
            else if (!wb_stall_o) req_sent <= 1'b0;
        end
    end

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
        .tWR                (tWR),
        .tREF               (tREF)
    ) u_sdram_ctrl (
        .*
    );


endmodule
