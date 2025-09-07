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
    input  logic            cmd_ready,
    input  logic            cmd_done,

    input  logic            precharge_ready,
    input  logic            active_ready,
    input  logic            write_ready,

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

localparam RD_SF_WIDTH = 5; // Read shift register width

/////////////////////////////////////////////////
// State Machine Declaration
/////////////////////////////////////////////////

// SDRAM Main Control State Machine
typedef enum logic [1:0] {
    RESET,  // Start up State
    INIT,   // SDRAM initialization
    ACCESS, // Access SDRAM
    REFRESH // Access SDRAM
} sdram_state_t;

/////////////////////////////////////////////////
// Signal Declaration
/////////////////////////////////////////////////

// main state machine
sdram_state_t               sdram_state, sdram_state_next;
logic                       s_INIT;
logic                       s_ACCESS;
logic                       s_REFRESH;

// registered input request
logic                       req_valid_q;
logic                       req_write_q;
logic [AW-1:0]              req_addr_q;
logic [DW-1:0]              req_wdata_q;
logic [DW/8-1:0]            req_byteenable_q;

// input bus status
logic                       req_act;            // bus request is accepted
logic                       req_done;           // bus request complete

// Address mapping to sdram bank, row, col
logic [1:0]                 bank;
logic [RAW-1:0]             row;
logic [CAW-1:0]             col;
logic [RAW-1:0]             addr_col;           // sdram column address

// Refresh counter
logic [REF_CNT_WIDTH-1:0]   ref_cnt;
logic                       ref_req;

// CL counter to indicate read data ready
logic                       read_req_send;
logic [RD_SF_WIDTH-1:0]     read_valid_pipe;    // Read valid pipeline

// SDRAM status indicator
logic                       row_activated;      // indicate a row is activated
logic                       precharged;         // indicate precharge is done and no row is activated
logic [RAW+1:0]             activated_bank_row; // activated bank and row
logic [RAW+1:0]             request_bank_row;   // request bank and row
logic                       precharge_done;
logic                       row_active_done;
logic                       open_new_row;       // request need to open a new row

// sdram command for arbitration
logic                       access_precharge;
logic                       access_active;
logic                       access_write;
logic                       access_read;
logic                       refresh_precharge;
logic                       refresh_refresh;

// granted sdram command
logic                       grant_precharge;
logic                       grant_refresh;
logic                       grant_active;
logic                       grant_write;
logic                       grant_read;

// state status
logic                       access_done;
logic                       refresh_done;

logic                       init_done_q;        // delay init_done by 1 cycle to match with state transition

/////////////////////////////////////////////////
// Main logic
/////////////////////////////////////////////////G

// ----------------------------------------------
// Input and Output Register for the system bus
// ----------------------------------------------

// register the input request
always_ff @(posedge clk) begin
    if (!rst_n) begin
        req_valid_q <= 1'b0;
    end
    else begin
        if (req_act) req_valid_q <= req_valid;
        else if (req_done) req_valid_q <= 1'b0;
    end
end

always_ff @(posedge clk) begin
    if (req_act) begin
        req_write_q      <= req_write;
        req_addr_q       <= req_addr;
        req_wdata_q      <= req_wdata;
        req_byteenable_q <= req_byteenable;
    end
end

// ----------------------------------------------
// Main state machine
// ----------------------------------------------

// Indicating current state
assign s_INIT    = (sdram_state == INIT);
assign s_ACCESS  = (sdram_state == ACCESS);
assign s_REFRESH = (sdram_state == REFRESH);

// state transition
always_ff @(posedge clk) begin
    if (!rst_n) begin
        sdram_state <= RESET;
    end
    else begin
        sdram_state <= sdram_state_next;
    end
end

always_comb begin
    sdram_state_next = sdram_state;
    case(sdram_state)
        RESET: sdram_state_next = INIT;
        INIT: if (init_done) sdram_state_next = ACCESS;
        ACCESS: if (access_done && ref_req) sdram_state_next = REFRESH;
        REFRESH: if (refresh_done) sdram_state_next = ACCESS;
        default: sdram_state_next = sdram_state;
    endcase
end

// ----------------------------------------------
// CAS Latency counter
// ----------------------------------------------
// In order to support pipelined read, use a shift register to generate desired delay
// Currently it takes CL + 2 cycle for the read data to appear on the response bus (rsp_*) after
// the read request is issued from sdram_ctrl module.
// The additional 2 cycle besides CL comes from the following:
//     - 1 cycle for the sdram_cmd module to register the internal request to the SDRAM interface
//     - 1 cycle for the sdram controller to receives the data from the SDRAM interface

assign read_req_send = grant_read;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        read_valid_pipe <= 'b0;
    end
    else begin
        read_valid_pipe <= {read_valid_pipe[RD_SF_WIDTH-2:0], read_req_send};
    end
end

always_ff @(posedge clk) begin
   rsp_rdata <= sdram_dq_in;
end

assign rsp_early_valid = cfg_cas_latency == 2 ? read_valid_pipe[RD_SF_WIDTH-3] : read_valid_pipe[RD_SF_WIDTH-2];
assign rsp_valid       = cfg_cas_latency == 2 ? read_valid_pipe[RD_SF_WIDTH-2] : read_valid_pipe[RD_SF_WIDTH-1];

// ----------------------------------------------
// SDRAM status
// ----------------------------------------------

// 1. Precharge and Active status

assign precharge_done  = grant_precharge & cmd_done;
assign row_active_done = grant_active    & cmd_done;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        row_activated <= 1'b0;
    end
    else begin
        if      (precharge_done)  row_activated <= 1'b0;
        else if (row_active_done) row_activated <= 1'b1;
    end
end

assign precharged = ~row_activated;

always_ff @(posedge clk) begin
    if (row_active_done) activated_bank_row <= {bank, row};
end

assign request_bank_row = {bank, row};

// open a new row when
// - row is not activated (precharged)
// - the next request target a different bank/row
assign open_new_row = precharged | (request_bank_row != activated_bank_row);

// 2. Refresh status

always_ff @(posedge clk) begin
    if (!rst_n) begin
        ref_cnt <= 'b0;
    end
    else begin
        if (s_INIT || grant_refresh && cmd_done) ref_cnt <= REFRESH_INTERVAL;
        else if (ref_cnt > 0) ref_cnt <= ref_cnt - 1'b1;
    end
end

assign ref_req = ref_cnt == 0;

// 3. SDRAM request status

assign req_done = grant_write | grant_read; // read/write only takes 1 cycle so grant means command is send and complete
assign req_ready = init_done_q & (~req_valid_q | req_done);

// ----------------------------------------------
// SDRAM State Machine Output Function Logic
// ----------------------------------------------

assign req_act = req_valid & req_ready;

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

always_ff @(posedge clk) begin
    if (!rst_n) init_done_q <= 1'b0;
    else init_done_q <= init_done;
end

/**

Implementation Note:

There are two type of requests: sdram access and sdram refresh. They are mapped to several SDRAM commands, including:
Precharge, Active, Read or Write, and Refresh.

Depending on the status and the request, it may requires one or more of the above command to be performed.
Each command will assert corresponding signal, and an arbiter will grant the command in the following order:
Precharge -> Active or Refresh -> Read or Write

For example, a sdram refresh request will always assert precharge and refresh signal. The arbiter will grant precharge first.
Once precharge cmd is completed, precharge signal is de-asserted and refresh cmd is granted and performed.
Once refresh cmd is completed, then the sdram refresh request is completed.

Another example, a sdram access request targeting a different row from the currently opened row.
This request will assert precharge, row active, and write signal. Precharge is first granted, followed by row active cmd
and finally write cmd.

The sdram access request comes in order so that sequences of sdram command to be performed is also in order.
The sdram refresh request could come anytime and it come when a sdram access request is performed. For non-burst mode.
We wait for the current sdram access request to complete before starting process the refresh request.

To accommodate this, two separate state is used: ACCESS and REFRESH state.

**/

// precharge is performed when a row is currently activated and need to open a new row
assign access_precharge = s_ACCESS & row_activated & req_valid_q & open_new_row;

// row active is performed when there are request pending and row is not activated (usually after a precharge command)
assign access_active = s_ACCESS & precharged & req_valid_q;

// write is performed when there are write request pending and row is activated
assign access_write = s_ACCESS & row_activated & req_valid_q & req_write_q;

// read is performed when there are read request pending and row is activated
assign access_read = s_ACCESS & row_activated & req_valid_q & ~req_write_q;

// precharge is performed when sdram need refresh
assign refresh_precharge = s_REFRESH & row_activated;

// refresh is performed after precharge complete
assign refresh_refresh = s_REFRESH & precharged;

// Main control logic
always_comb begin

    // assign default value to most used value so we don't have to assign them again in the case statement
    cmd_valid = 1'b0;
    cmd_type  = `CMD_NOP;
    cmd_ba    = 'b0;
    cmd_data  = 'b0;
    cmd_dqm   = 'b0;
    cmd_addr  = 'b0;

    grant_precharge = 1'b0;
    grant_refresh   = 1'b0;
    grant_active    = 1'b0;
    grant_write     = 1'b0;
    grant_read      = 1'b0;

    // command arbitration
    if (access_precharge || refresh_precharge) begin
        grant_precharge = 1'b1;
        cmd_valid = cmd_ready & precharge_ready;
        cmd_type = `CMD_PRECHARGE;
        cmd_addr[10] = 1'b1;
    end
    else if (refresh_refresh) begin
        grant_refresh = 1'b1;
        cmd_valid = cmd_ready ;
        cmd_type = `CMD_REFRESH;
    end
    else if (access_active) begin
        grant_active = 1'b1;
        cmd_valid = cmd_ready & active_ready;
        cmd_type = `CMD_ACTIVE;
        cmd_ba   = bank;
        cmd_addr = row;
    end
    else if (access_write) begin
        grant_write = 1'b1;
        cmd_valid = cmd_ready & write_ready;
        cmd_type  = `CMD_WRITE;
        cmd_ba    = bank;
        cmd_data  = req_wdata_q;
        cmd_dqm   = ~req_byteenable_q;
        cmd_addr  = {addr_col[RAW-1:11], 1'b0, addr_col[9:0]};
    end
    else if (access_read) begin
        grant_read = 1'b1;
        cmd_valid = cmd_ready;
        cmd_type  = `CMD_READ;
        cmd_ba    = bank;
        cmd_dqm   = ~req_byteenable_q;
        cmd_addr  = {addr_col[RAW-1:11], 1'b0, addr_col[9:0]};
    end
end

assign access_done = precharge_ready; // precharge ready means the current sdram request has been completed.
assign refresh_done = refresh_refresh & cmd_done;

/////////////////////////////////////////////////
// SIMULATION
/////////////////////////////////////////////////

`ifdef SIMULATION

logic [95:0] sdram_operation_string;
always_comb begin
    case (1)
        grant_precharge: sdram_operation_string = "PRECHARGE";
        grant_refresh:   sdram_operation_string = "AUTO_REFRESH";
        grant_active:    sdram_operation_string = "ROW_ACTIVE";
        grant_write:     sdram_operation_string = "WRITE";
        grant_read:      sdram_operation_string = "READ";
        default:         sdram_operation_string = "IDLE";
    endcase
end

`endif

endmodule
