// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 09/07/2025
//
// -------------------------------------------------------------------
// Functions:
//     - Generate write and read request to sdram controller
// -------------------------------------------------------------------

module sdram_driver #(
    parameter AW = 23,              // address width
    parameter DW = 16,              // data width
    parameter ADDR_LO = 0,          // starting address
    parameter ADDR_HI = 1<<AW-1     // ending address
)(
    input  logic        clk,
    input  logic        rst_n,

    // System Bus
    output logic            req_valid,
    output logic            req_write,
    output logic [AW-1:0]   req_addr,
    output logic [DW-1:0]   req_wdata,
    output logic [DW/8-1:0] req_byteenable,
    input  logic            req_ready,

    input  logic            rsp_early_valid,
    input  logic            rsp_valid,
    input  logic [DW-1:0]   rsp_rdata,

    output logic            complete,
    output logic            error
);

localparam BW = DW/8;

/////////////////////////////////////////////////
// State Machine Declaration
/////////////////////////////////////////////////

typedef enum logic [1:0] {
    ST_IDLE,
    ST_WRITE,
    ST_READ,
    ST_DONE
} state_t;

state_t state, state_next;

/////////////////////////////////////////////////
// Signal Declaration
/////////////////////////////////////////////////

logic [AW-1:0] addr_cnt;
logic [DW-1:0] rcv_addr_cnt;
logic          last_addr;
logic          req_fire;
logic          data_error;

/////////////////////////////////////////////////
// Main logic
/////////////////////////////////////////////////

assign req_fire = req_valid & req_ready;
assign data_error = rsp_valid & (rsp_rdata != rcv_addr_cnt);
assign last_addr = (req_addr <= ADDR_HI) && (req_addr + BW > ADDR_HI);

always_ff @(posedge clk) begin
    if (!rst_n) state <= ST_IDLE;
    else        state <= state_next;
end

always_ff @(posedge clk) begin
    if (!rst_n) begin
        addr_cnt  <= '0;
    end else begin
        if (req_fire) begin
            if (last_addr) addr_cnt <= '0;
            else addr_cnt <= addr_cnt + BW;
        end
    end
end

always_ff @(posedge clk) begin
    if (!rst_n) begin
        rcv_addr_cnt  <= '0;
        error <= 1'b0;
    end else begin
        if (rsp_valid) begin
            error <= error | data_error;
            rcv_addr_cnt <= rcv_addr_cnt + BW;
        end
    end
end

always_comb begin
    state_next = state;
    case (state)
        ST_IDLE: begin
            state_next = ST_WRITE;
        end
        ST_WRITE: begin
            if (req_fire && last_addr) begin
                state_next = ST_READ;
            end
        end
        ST_READ: begin
            if (req_fire && last_addr) begin
                state_next = ST_DONE;
            end
        end
        default: state_next = state;
    endcase
end

always_comb begin
    req_valid     = 1'b0;
    req_write     = 1'b0;
    req_addr      = addr_cnt;
    req_wdata     = addr_cnt;   // write data = addr
    req_byteenable= {DW/8{1'b1}};
    complete      = 1'b0;

    case (state)
        ST_WRITE: begin
            req_valid = 1'b1;
            req_write = 1'b1;
        end

        ST_READ: begin
            req_valid = 1'b1;
            req_write = 1'b0;
         end

        ST_DONE: begin
            complete = 1'b1;
        end
    endcase
end

/////////////////////////////////////////////////
// SIMULATION
/////////////////////////////////////////////////

`ifdef SIMULATION
// Monitor read responses
always_comb begin
    if (data_error) begin
        $display("ERROR: Read data mismatch on address: %h. Expected %h. Actual = %h", rcv_addr_cnt, rcv_addr_cnt, rsp_rdata);
    end
end
`endif

endmodule