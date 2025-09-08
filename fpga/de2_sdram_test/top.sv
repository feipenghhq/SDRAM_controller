// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 09/07/2025
//
// -------------------------------------------------------------------

module top
(
    input                   CLOCK_50,    // 50 MHz
    input                   RESETn,      // Used as RESET, low active

    output [1:0]            LEDR,

    // SDRAM interface
    output logic            SDRAM_CLK,
    output logic            SDRAM_CKE,
    output logic            SDRAM_CS_N,
    output logic            SDRAM_RAS_N,
    output logic            SDRAM_CAS_N,
    output logic            SDRAM_WE_N,
    output logic [11:0]     SDRAM_ADDR,
    output logic [1:0]      SDRAM_BA,
    output logic [1:0]      SDRAM_DQM,
    inout  wire  [15:0]     SDRAM_DQ
);

fpga_sdram_test #(
    .CLK_FREQ   (50),
    .DW         (16),
    .AW         (23),
    .RAW        (12),
    .CAW        (8 ),
    .tRAS       (45),
    .tRC        (68),
    .tRCD       (20),
    .tRFC       (68),
    .tRP        (20),
    .tRRD       (15),
    .tWR        (15),
    .tREF       (64)
)
u_sdram_test (
    .clk                (CLOCK_50),
    .rst_n              (RESETn),
    .complete           (LEDR[0]),
    .error              (LEDR[1]),
    .sdram_clk_out      (SDRAM_CLK),
    .sdram_cke          (SDRAM_CKE),
    .sdram_cs_n         (SDRAM_CS_N),
    .sdram_ras_n        (SDRAM_RAS_N),
    .sdram_cas_n        (SDRAM_CAS_N),
    .sdram_we_n         (SDRAM_WE_N),
    .sdram_addr         (SDRAM_ADDR),
    .sdram_ba           (SDRAM_BA),
    .sdram_dqm          (SDRAM_DQM),
    .sdram_dq           (SDRAM_DQ)
);

endmodule
