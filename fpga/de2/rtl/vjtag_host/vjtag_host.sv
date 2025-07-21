// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: VJtag Host
// Author: Heqing Huang
// Date Created: 07/11/2025
//
// -------------------------------------------------------------------
// vjtag_host: Top level for VJtag Host
// -------------------------------------------------------------------

module vjtag_host #(
    parameter AW = 16,
    parameter DW = 16
)(
    input  logic           clk,
    input  logic           rst_n,

    // system bus interface
    output logic           rst_n_out,   // reset output
    output logic [AW-1:0]  address,     // address
    output logic           wvalid,      // write request
    output logic [DW-1:0]  wdata,       // write data
    input  logic           wready,      // write ready
    output logic           rvalid,      // read request
    input  logic           rready,      // read ready
    input  logic           rrvalid,     // read response valid
    input  logic [DW-1:0]  rdata        // read data
);

    // Wires to connect VJTAG IP and control module
    logic [7:0] ir_in, ir_out;
    logic       tck, tdi, tdo;
    logic       cdr, cir, e1dr, e2dr, pdr, sdr, udr, uir;

    // Instantiate VJTAG IP
    vjtag_ip u_vjtag_ip (
        .ir_out             (ir_out),
        .tdo                (tdo),
        .ir_in              (ir_in),
        .tck                (tck),
        .tdi                (tdi),
        .virtual_state_cdr  (cdr),
        .virtual_state_cir  (cir),
        .virtual_state_e1dr (e1dr),
        .virtual_state_e2dr (e2dr),
        .virtual_state_pdr  (pdr),
        .virtual_state_sdr  (sdr),
        .virtual_state_udr  (udr),
        .virtual_state_uir  (uir)
    );

    // Instantiate VJTAG control module
    vjtag_ctrl #(
        .AW(AW),
        .DW(DW)
    ) u_vjtag_ctrl (
        .ir_out     (ir_out),
        .tdo        (tdo),
        .ir_in      (ir_in),
        .tck        (tck),
        .tdi        (tdi),
        .cdr        (cdr),
        .cir        (cir),
        .e1dr       (e1dr),
        .e2dr       (e2dr),
        .pdr        (pdr),
        .sdr        (sdr),
        .udr        (udr),
        .uir        (uir),
        .clk        (clk),
        .rst_n      (rst_n),
        .rst_n_out  (rst_n_out),
        .address    (address),
        .wvalid     (wvalid),
        .wdata      (wdata),
        .wready     (wready),
        .rvalid     (rvalid),
        .rready     (rready),
        .rrvalid    (rrvalid),
        .rdata      (rdata)
    );

endmodule
