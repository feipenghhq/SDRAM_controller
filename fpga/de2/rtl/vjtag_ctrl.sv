// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: VJtag Host
// Author: Heqing Huang
// Date Created: 07/11/2025
//
// -------------------------------------------------------------------
// vjtag_ctrl: control logic for bus access
// -------------------------------------------------------------------

module vjtag_ctrl #(
    parameter AW = 16,   // address width
    parameter DW = 16    // data width
) (

    // vjtag ip (on tck clock domain)
    output logic [7:0]      ir_out,     // Virtual JTAG instruction register output.
                                        // The value is captured whenever virtual_state_cir is high
    output logic            tdo,        // Writes to the TDO pin on the device
    input  logic [7:0]      ir_in,      // Virtual JTAG instruction register data.
                                        // The value is available and latched when virtual_state_uir is high
    input  logic            tck,        // JTAG test clock
    input  logic            tdi,        // TDI input data on the device. Used when virtual_state_sdr is high
    input  logic            cdr,        // virtual JTAG is in Capture_DR state
    input  logic            cir,        // virtual JTAG is in Capture_IR state
    input  logic            e1dr,       // virtual JTAG is in Exit1_DR state
    input  logic            e2dr,       // virtual JTAG is in Exit2_DR state
    input  logic            pdr,        // virtual JTAG is in Pause_DR state
    input  logic            sdr,        // virtual JTAG is in Shift_DR state
    input  logic            udr,        // virtual JTAG is in Update_DR state
    input  logic            uir,        // virtual JTAG is in Update_IR state

    // system bus (on clk clock domain)
    input  logic            clk,
    input  logic            rst_n,
    output logic            rst_n_out,  // reset output
    output logic [AW-1:0]   address,    // address
    output logic            wvalid,     // write request
    output logic [DW-1:0]   wdata,      // write data
    input  logic            wready,     // write ready
    output logic            rvalid,     // read request
    input  logic            rready,     // read ready
    input  logic            rrvalid,    // read response valid
    input  logic [DW-1:0]   rdata       // read data
);

///////////////////////////////////////
// Signal Declaration
///////////////////////////////////////

localparam IRW = 8;                 // IR width
localparam DRW = AW + DW;           // DR width

// Commands
localparam  CMD_READ  = 8'h1,
            CMD_WRITE = 8'h2,
            CMD_RST_A = 8'hFE,      // reset assertion
            CMD_RST_D = 8'hFF;      // reset de-assertion

// -- tck domain signal --

logic [1:0]     rst_n_dsync_tck;
logic [DRW-1:0] dr;
logic [DW-1:0]  rdata_tck;          // synchronized rdata on TCK domain


// -- clk domain signal --

logic [1:0]     udr_dsync_sys;      // double synchronizer for udr to CLK domain
logic           udr_sys;            // synchronized udr on CLK domain
logic [IRW-1:0] ir_sys;             // synchronized ir on CLK domain
logic [DRW-1:0] dr_sys;             // synchronized dr on CLK domain

logic           udr_q_sys;          // delayed version of udr_sys
logic           update;             // update the ir and dr on CLK domain
logic           request;            // request to initiate bus request

// bus request state machine
localparam      IDLE = 0,
                REQ  = 1,
                READ = 2;

logic [1:0]     state, state_next;

logic           is_write;
logic           is_read;
logic [DW-1:0]  rdata_q;

///////////////////////////////////////
// Main logic
///////////////////////////////////////

// Implementation Note:
// - IR holds the Bus command, and DR holds the remaining data (address, write data)
// When Host send transaction through VJTAG to FPGA:
// - ir_in contains the command.
// - When the `sdr` signal is asserted, the remaining data are shifted into the **DR** via the `tdi` pin.
// - When shifting is complete, `sdr` is de-asserted and `udr` is asserted.
// - The `tck` signal toggles only during active data shifting. Once `udr` is asserted, `tck` remains idle until
//   the next transaction begins. `udr` also remains asserted until the next transaction begins.

// ------------------------------------
//              TCK domain
// ------------------------------------

// Data Register (dr)
always_ff @(posedge tck) begin
    if (cdr) dr <= {{AW{1'b0}}, rdata_q}; // rdata_q is in CLK domain but considered as quasi-static
    if (sdr) dr <= {tdi, dr[DRW-1:1]};
end

// tdo
assign tdo = dr[0];

// ir_out
assign ir_out = ir_in;

// ------------------------------------
//              CLK domain
// ------------------------------------

always @(posedge clk) begin
    if (!rst_n) request <= 1'b0;
    else        request <= update;
end

// Bus request state machine
always_ff @(posedge clk) begin
    if (!rst_n) state <= IDLE;
    else        state <= state_next;
end

always_comb begin
    state_next = state;
    case(state)
        IDLE: begin
            if (request) begin
                if      (is_write) state_next = wready ? IDLE : REQ;
                else if (is_read)  state_next = rready ? READ : REQ;
            end
        end
        REQ: begin
            if      (wvalid && wready) state_next = IDLE;
            else if (rvalid && rready) state_next = READ;
        end
        READ: begin
            if (rrvalid) state_next = IDLE;
        end
    endcase
end

always_ff @(posedge clk) begin
    if (!rst_n) begin
        wvalid <= 1'b0;
        rvalid <= 1'b0;
    end
    else begin
        // Note: use next state here
        case(state_next)
            IDLE: begin
                wvalid <= request & is_write;
                rvalid <= request & is_read;
            end
            REQ: begin
                wvalid <= is_write;
                rvalid <= is_read;
            end
            READ: begin
                if (state != READ) rvalid <= is_read;
            end
        endcase
    end
end

assign is_write = ir_sys == CMD_WRITE;
assign is_read  = ir_sys == CMD_READ;
assign wdata    = dr_sys[DW-1:0];
assign address  = dr_sys[AW+DW-1:DW];

// Handle read data
always @(posedge clk) begin
    if (rrvalid) rdata_q <= rdata;
end


// Handle Reset Command
always @(posedge clk) begin
    if (!rst_n) rst_n_out <= 1'b1;
    else begin
        if (request) begin
            if      (ir_sys == CMD_RST_A) rst_n_out <= 1'b0;
            else if (ir_sys == CMD_RST_D) rst_n_out <= 1'b1;
        end
    end
end

// ------------------------------------
//              CDC Logic
// ------------------------------------

// -- TCK -> CLK --

// synchronize udr
always @(posedge clk) begin
    if (!rst_n) udr_dsync_sys <= 2'b0;
    else        udr_dsync_sys <= {udr_dsync_sys[0], udr};
end
assign udr_sys = udr_dsync_sys[1];

// create a pulse from udr
always @(posedge clk) begin
    if (!rst_n) udr_q_sys <= 1'b0;
    else        udr_q_sys <= udr_sys;
end
assign update = udr_sys & ~udr_q_sys;

// use the udr pulse as a qualifier to capture ir and dr to CLK domain
always @(posedge clk) begin
    if (update) begin
        ir_sys <= ir_in;
        dr_sys <= dr;
    end
end

// -- CLK -> TCK --
// TCK is usually running slower then CLK.
// When VJTAG issue command to read the data back, the read data should already been captured in rdata_q register.
// We can consider rdata_q as quasi-static hence no need to synchronize it from CLK to TCK

endmodule
