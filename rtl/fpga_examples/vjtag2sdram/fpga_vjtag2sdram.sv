// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 07/20/2025
//
// -------------------------------------------------------------------
// Test SDRAM
// -------------------------------------------------------------------

module fpga_vjtag2sdram #(
    parameter CLK_FREQ  = 130,   // (MHz) clock frequency
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
    input                   clk,
    input                   rst_n,

    // SDRAM interface
    output logic            sdram_clk_out,          // Clock output.
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

    logic           sdram_clk;
    logic [2:0]     cfg_cas_latency;

    // Wishbone interface (same direction as vjtag2wb)
    logic           wb_cyc_o;
    logic           wb_stb_o;
    logic           wb_we_o;
    logic [AW-1:0]  wb_adr_o;
    logic [DW-1:0]  wb_dat_i;
    logic [DW-1:0]  wb_dat_o;
    logic           wb_ack_i;
    logic           wb_stall_i;


    altpll_top #(.CLK_FREQ(CLK_FREQ))
    u_altpll_top (
        .*
    );

    vjtag2wb #(
        .ADDR_WIDTH(AW),
        .DATA_WIDTH(DW)
    )
    u_vjtag2wb(
        .clk        (sdram_clk),
        .rst_n_out  (),
        .*
    );

    wbsdram #(
        .CLK_FREQ   (CLK_FREQ),
        .AW         (AW),
        .DW         (DW),
        .RAW        (RAW),
        .CAW        (CAW),
        .tRAS       (tRAS),
        .tRC        (tRC),
        .tRCD       (tRCD),
        .tRFC       (tRFC),
        .tRP        (tRP),
        .tRRD       (tRRD),
        .tWR        (tWR),
        .tREF       (tREF)
    ) u_wbsdram (
        .clk                (sdram_clk),
        .wb_dat_i           (wb_dat_o),
        .wb_dat_o           (wb_dat_i),
        .wb_cyc_i           (wb_cyc_o),
        .wb_stb_i           (wb_stb_o),
        .wb_we_i            (wb_we_o ),
        .wb_adr_i           (wb_adr_o),
        .wb_sel_i           ({DW/8{1'b1}}),
        .wb_ack_o           (wb_ack_i),
        .wb_stall_o         (wb_stall_i),
        .cfg_burst_length   (0),
        .cfg_burst_type     (0),
        .cfg_burst_mode     (0),
        .cfg_cas_latency    (cfg_cas_latency),
        .*
    );

endmodule
