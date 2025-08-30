// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 08/26/2025
//
// -------------------------------------------------------------------
// Main SDRAM control logic
// -------------------------------------------------------------------

`include "sdram_inc.svh"

module sdram_ctrl #(
    parameter CLK_FREQ  = 100,      // (MHz) clock frequency
    parameter AW        = 24,       // Bus Address width. Should match with SDRAM size
    parameter DW        = 16,       // Bus Data width
    parameter RAW       = 12,       // SDRAM Address width
    parameter CAW       = 9,        // SDRAM Column address width
    parameter tWR       = 0,        // (ns) WRITE recovery time
    parameter tREF      = 64        // (ms) Refresh Period
) (
    input  logic            clk,
    input  logic            rst_n,

    // initialization status
    input  logic            init_done,

    // Command Input/Output
    output logic            cmd_valid,          // a single pulse for each command
    output logic [3:0]      cmd_type,
    output logic [RAW-1:0]  cmd_addr,
    output logic [DW-1:0]   cmd_data,
    output logic [1:0]      cmd_ba,
    output logic [DW/8-1:0] cmd_dqm,
    input  logic            cmd_done,
    input  logic            cmd_early_done,
    input  logic            cmd_wip,

    // SDRAM Config
    input  logic [2:0]      cfg_burst_length,   // SDRAM Mode register: Burst Length
    input  logic            cfg_burst_type,     // SDRAM Mode register: Burst Type
    input  logic [2:0]      cfg_cas_latency,    // SDRAM Mode register: CAS Latency
    input  logic            cfg_burst_mode,     // SDRAM Mode register: Write Burst Mode

    input  logic [DW-1:0]   sdram_dq_in,

    // System Bus
    input  logic            req_valid,          // request valid
    input  logic            req_write,          // 0: read request. 1: write request
    input  logic [AW-1:0]   req_addr,           // address
    input  logic [DW-1:0]   req_wdata,          // write data
    input  logic [DW/8-1:0] req_byteenable,     // byte enable
    output logic            req_ready,          // ready

    output logic            rsp_early_valid,    // one cycle before read data valid
    output logic            rsp_valid,          // read data valid
    output logic [DW-1:0]   rsp_rdata           // read data
);

/////////////////////////////////////////////////
// Local Parameter
/////////////////////////////////////////////////

localparam cWR  = `SDRAM_CEIL_DIV(tWR  * CLK_FREQ, 1000);   // (CLK Cycle) WRITE recovery time

// Bus Decode
localparam ROW_COUNT = 2**RAW; // SDRAM row count
localparam NUM_BYTE  = DW / 8; // Number of byte
localparam BW        = $clog2(NUM_BYTE); // Address With to select the byte

localparam REFRESH_INTERVAL = (tREF * 1000 * CLK_FREQ / ROW_COUNT); // Refresh counter threshold
localparam REF_CNT_WIDTH = $clog2(REFRESH_INTERVAL);
localparam CMD_CNT_WIDTH = 4; // Command counter width

localparam RD_SF_WIDTH = 5; // Read shift register width

/////////////////////////////////////////////////
// State Machine Declaration
/////////////////////////////////////////////////

// SDRAM Main Control State Machine
typedef enum logic [3:0] {
    RESET,        // Start up State
    INIT,         // SDRAM initialization
    MODE_REG_SET, // Mode Register set
    IDLE,         // IDLE state (after bank have been pre-charged)
    ROW_ACTIVE,   // Active a row
    WRITE,        // Write without auto precharge
    READ,         // Read without auto precharge
    PRECHARGE,    // Precharge the bank
    AUTO_REFRESH  // Auto Refresh
} sdram_state_t;

/////////////////////////////////////////////////
// Signal Declaration
/////////////////////////////////////////////////

// main state machine
sdram_state_t               sdram_state, sdram_state_next;
logic                       s_RESET;
logic                       s_INIT;
logic                       s_IDLE;
logic                       s_ROW_ACTIVE;
logic                       s_WRITE;
logic                       s_READ;
logic                       s_PRECHARGE;
logic                       s_AUTO_REFRESH;
logic                       arc_RESET_to_INIT;
logic                       arc_INIT_to_IDLE;
logic                       arc_IDLE_to_ROW_ACTIVE;
logic                       arc_IDLE_to_PRECHARGE;
logic                       arc_IDLE_to_READ;
logic                       arc_IDLE_to_WRITE;
logic                       arc_ROW_ACTIVE_to_WRITE;
logic                       arc_ROW_ACTIVE_to_READ;
logic                       arc_WRITE_to_IDLE;
logic                       arc_WRITE_to_WRITE;
logic                       arc_WRITE_to_READ;
logic                       arc_WRITE_to_PRECHARGE;
logic                       arc_READ_to_IDLE;
logic                       arc_PRECHARGE_to_AUTO_REFRESH;
logic                       arc_PRECHARGE_to_ROW_ACTIVE;
logic                       arc_AUTO_REFRESH_to_IDLE;
logic                       arc_AUTO_REFRESH_to_ROW_ACTIVE;
logic                       to_IDLE;
logic                       to_ROW_ACTIVE;
logic                       to_READ;
logic                       to_WRITE;
logic                       to_PRECHARGE;
logic                       to_REFRESH;

// registered input request
logic                       req_read_q;
logic                       req_write_q;
logic [AW-1:0]              req_addr_q;
logic [DW-1:0]              req_wdata_q;
logic [DW/8-1:0]            req_byteenable_q;

logic                       req_act;            // bus request is accepted
logic                       req_done;           // bus request complete
logic                       int_req;            // internal bus request pending

// Address mapping to sdram {bank, row, col}
logic [1:0]                 bank;               // band address
logic [RAW-1:0]             row;                // row address
logic [CAW-1:0]             col;                // column address

// Refresh counter
logic [REF_CNT_WIDTH-1:0]   ref_cnt;
logic                       ref_req;

// CL counter to indicate read data ready
logic                       cmd_is_read;
logic [RD_SF_WIDTH-1:0]     read_valid_pipe;    // Read valid pipeline

// SDRAM bank/row status
logic                       row_active_done;
logic                       precharge_done;
logic                       bank_precharged;    // indicate a precharge has already been performed
logic [RAW+1:0]             active_ba_row;      // activated bank and row
logic [RAW+1:0]             next_ba_row;        // next bank and row
logic                       open_new_row;       // new request need to open a new row

// misc
logic [RAW-1:0]             addr_col;           // sdram column address

/////////////////////////////////////////////////
// Main logic
/////////////////////////////////////////////////

// ----------------------------------------------
// Input and Output Register for the system bus
// ----------------------------------------------

// register the input request
always_ff @(posedge clk) begin
    if (!rst_n) begin
        req_read_q   <= 1'b0;
        req_write_q  <= 1'b0;
    end
    else begin
        if (req_act) begin
            req_read_q   <= ~req_write;
            req_write_q  <= req_write;
        end
        else if (req_done) begin
            req_read_q   <= 1'b0;
            req_write_q  <= 1'b0;
        end
    end
end

always_ff @(posedge clk) begin
    if (req_act) begin
        req_addr_q       <= req_addr;
        req_wdata_q      <= req_wdata;
        req_byteenable_q <= req_byteenable;
    end
end

assign req_ready = (~int_req & ~s_RESET & ~s_INIT) | req_done;   // TBD: Make this flopped version for better timing

always_ff @(posedge clk) begin
   rsp_rdata <= sdram_dq_in;
end

assign rsp_early_valid = cfg_cas_latency == 2 ? read_valid_pipe[RD_SF_WIDTH-3] : read_valid_pipe[RD_SF_WIDTH-2];
assign rsp_valid       = cfg_cas_latency == 2 ? read_valid_pipe[RD_SF_WIDTH-2] : read_valid_pipe[RD_SF_WIDTH-1];

// ----------------------------------------------
// Main state machine
// ----------------------------------------------

// Indicating current state
assign s_RESET        = (sdram_state == RESET);
assign s_INIT         = (sdram_state == INIT);
assign s_IDLE         = (sdram_state == IDLE);
assign s_ROW_ACTIVE   = (sdram_state == ROW_ACTIVE);
assign s_WRITE        = (sdram_state == WRITE);
assign s_READ         = (sdram_state == READ);
assign s_PRECHARGE    = (sdram_state == PRECHARGE);
assign s_AUTO_REFRESH = (sdram_state == AUTO_REFRESH);

// state transaction arc

assign arc_RESET_to_INIT = s_RESET;

assign arc_INIT_to_IDLE = s_INIT & init_done;

assign arc_IDLE_to_ROW_ACTIVE = s_IDLE & ~ref_req & int_req     & bank_precharged;
assign arc_IDLE_to_WRITE      = s_IDLE & ~ref_req & req_write_q & ~open_new_row;
assign arc_IDLE_to_READ       = s_IDLE & ~ref_req & req_read_q  & ~open_new_row;
assign arc_IDLE_to_PRECHARGE  = s_IDLE & (ref_req | int_req     & open_new_row);

assign arc_ROW_ACTIVE_to_WRITE = s_ROW_ACTIVE & cmd_done & req_write_q;
assign arc_ROW_ACTIVE_to_READ  = s_ROW_ACTIVE & cmd_done & req_read_q;

assign arc_WRITE_to_IDLE      = s_WRITE & cmd_done & ~ref_req & ~int_req;
assign arc_WRITE_to_WRITE     = s_WRITE & cmd_done & ~ref_req & req_write_q & ~open_new_row;
assign arc_WRITE_to_READ      = s_WRITE & cmd_done & ~ref_req & req_read_q  & ~open_new_row;
assign arc_WRITE_to_PRECHARGE = s_WRITE & cmd_done & (ref_req | int_req     & open_new_row);

assign arc_READ_to_IDLE = s_READ & cmd_done;

assign arc_PRECHARGE_to_AUTO_REFRESH = s_PRECHARGE & cmd_done & ref_req;
assign arc_PRECHARGE_to_ROW_ACTIVE   = s_PRECHARGE & cmd_done & ~ref_req;

assign arc_AUTO_REFRESH_to_IDLE       = s_AUTO_REFRESH & cmd_done & ~int_req;
assign arc_AUTO_REFRESH_to_ROW_ACTIVE = s_AUTO_REFRESH & cmd_done & int_req;

// state transition
always_ff @(posedge clk) begin
    if (!rst_n) begin
        sdram_state <= RESET;
    end
    else begin
        sdram_state <= sdram_state_next;
    end
end

assign to_IDLE = arc_INIT_to_IDLE | arc_WRITE_to_IDLE | arc_READ_to_IDLE | arc_AUTO_REFRESH_to_IDLE;
assign to_ROW_ACTIVE = arc_IDLE_to_ROW_ACTIVE | arc_PRECHARGE_to_ROW_ACTIVE | arc_AUTO_REFRESH_to_ROW_ACTIVE;
assign to_READ = arc_IDLE_to_READ | arc_ROW_ACTIVE_to_READ | arc_WRITE_to_READ;
assign to_WRITE = arc_IDLE_to_WRITE | arc_ROW_ACTIVE_to_WRITE | arc_WRITE_to_WRITE;
assign to_PRECHARGE = arc_IDLE_to_PRECHARGE | arc_WRITE_to_PRECHARGE;
assign to_REFRESH = arc_PRECHARGE_to_AUTO_REFRESH;

always_comb begin
    case (1)
        arc_RESET_to_INIT:  sdram_state_next = INIT;
        to_IDLE:            sdram_state_next = IDLE;
        to_ROW_ACTIVE:      sdram_state_next = ROW_ACTIVE;
        to_READ:            sdram_state_next = READ;
        to_WRITE:           sdram_state_next = WRITE;
        to_PRECHARGE:       sdram_state_next = PRECHARGE;
        to_REFRESH:         sdram_state_next = AUTO_REFRESH;
        default:            sdram_state_next = sdram_state;
    endcase
end

// ----------------------------------------------
// Refresh counter
// ----------------------------------------------
always_ff @(posedge clk) begin
    if (!rst_n) begin
        ref_cnt <= 'b0;
    end
    else begin
        if (arc_INIT_to_IDLE || arc_PRECHARGE_to_AUTO_REFRESH) ref_cnt <= REFRESH_INTERVAL;
        else if (ref_cnt > 0) ref_cnt <= ref_cnt - 1'b1;
    end
end

assign ref_req = ref_cnt == 0;

// ----------------------------------------------
// CAS Latency counter
// ----------------------------------------------
// In order to support pipelined read, use a shift register to generate desired delay

assign cmd_is_read = cmd_valid & (cmd_type == `CMD_READ);

always_ff @(posedge clk) begin
    if (!rst_n) begin
        read_valid_pipe <= 'b0;
    end
    else begin
        read_valid_pipe <= {read_valid_pipe[RD_SF_WIDTH-2:0], cmd_is_read};
    end
end

// ----------------------------------------------
// SDRAM bank/row status
// ----------------------------------------------

assign row_active_done = s_ROW_ACTIVE & cmd_done;
assign precharge_done  = s_PRECHARGE  & cmd_done;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        bank_precharged <= 1'b1;
    end
    else begin
        if      (precharge_done)  bank_precharged <= 1'b1;
        else if (row_active_done) bank_precharged <= 1'b0;
    end
end

always_ff @(posedge clk) begin
    if (row_active_done) active_ba_row <= {bank, row};
end

// open a new row when
// - bank is precharged so no bank/row is active
// - the next request target a different bank/row
assign open_new_row = bank_precharged | (next_ba_row != active_ba_row);
assign next_ba_row = {bank, row};

// ----------------------------------------------
// SDRAM State Machine Output Function Logic
// ----------------------------------------------

assign req_act = req_valid & req_ready;
assign int_req = req_read_q | req_write_q;

// Decode the address to sdram bank, row, col
assign {bank, row, col} = req_addr_q[AW-1:BW];

// Column address
generate
if (CAW > 10) begin
    assign addr_col[9:0]        = col[9:0];
    assign addr_col[10]         = 1'b0;
    assign addr_col[CAW-1+1:11] = col[CAW-1:10];
end
else begin
    assign addr_col[CAW-1:0]   = col;
    assign addr_col[RAW-1:CAW] = 'b0;
end
endgenerate

always_comb begin

    // assign default value to most used value so we don't have to assign them again in the case statement
    cmd_valid = 1'b0;
    cmd_type = `CMD_NOP;
    cmd_ba   = bank;
    cmd_data = req_wdata_q;
    cmd_dqm = ~req_byteenable_q;
    cmd_addr = {addr_col[RAW-1:11], 1'b0, addr_col[9:0]};
    req_done = 1'b0;

    // use the next state here
    case(sdram_state_next)
        IDLE: begin
            cmd_valid = 1'b0;
        end
        ROW_ACTIVE: begin
            cmd_valid = ~cmd_wip;
            cmd_type = `CMD_ACTIVE;
            cmd_addr = row;
        end
        WRITE: begin
            cmd_valid = ~cmd_wip;
            cmd_type = `CMD_WRITE;
            // For pipelined design, write cmd is considered completed 1 cycle before the write request is presented
            // in the SDRAM interface which is when cmd_done asserted. One special case is the before entering the
            // write state, the cmd is considered done for the first write request
            req_done = cmd_done | (sdram_state_next != WRITE);
        end
        READ: begin
            cmd_valid = ~cmd_wip;
            cmd_type = `CMD_READ;
            req_done = cmd_done;
        end
        PRECHARGE: begin
            cmd_valid = ~cmd_wip;
            cmd_type = `CMD_PRECHARGE;
            cmd_addr[10] = 1'b1;
        end
        AUTO_REFRESH: begin
            cmd_valid = ~cmd_wip;
            cmd_type = `CMD_REFRESH;
        end
    endcase

end

/////////////////////////////////////////////////
// SIMULATION
/////////////////////////////////////////////////

`ifdef SIMULATION
// Showing state in STRING
logic [95:0] sdram_state_str;
always_comb begin
    case (sdram_state)
        RESET:        sdram_state_str = "RESET     ";
        INIT:         sdram_state_str = "INIT      ";
        MODE_REG_SET: sdram_state_str = "MODE_REG  ";
        IDLE:         sdram_state_str = "IDLE      ";
        ROW_ACTIVE:   sdram_state_str = "ROW_ACTIVE";
        WRITE:        sdram_state_str = "WRITE     ";
        READ:         sdram_state_str = "READ      ";
        PRECHARGE:    sdram_state_str = "PRECHARGE ";
        AUTO_REFRESH: sdram_state_str = "AUTO_REFRESH";
        default:      sdram_state_str = "UNKNOWN   ";
    endcase
end

`endif

endmodule
