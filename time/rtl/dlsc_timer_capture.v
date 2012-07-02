// 
// Copyright (c) 2012, Daniel Strother < http://danstrother.com/ >
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//   - Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//   - Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in the
//     documentation and/or other materials provided with the distribution.
//   - The name of the author may not be used to endorse or promote products
//     derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
// WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
// EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
// TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

// Module Description:
// Event capture module. Has up to 256 trigger inputs and up to 16 capture
// channels. Each capture channel can monitor 1 of the inputs at a time. When
// a rising and/or falling edge is detected, the capture channel records the
// timestamp of the event in a shared FIFO. Each channel has a prescaler that
// can be used to reduce the rate of events captured.

module dlsc_timer_capture #(
    parameter INPUTS        = 1,                // number of event inputs (1-256)
    parameter META          = 1,                // bits of metadata per event input (1-32)
    parameter CHANNELS      = INPUTS,           // number of capture channels (1-16)
    parameter NOMUX         = 1,                // disable input muxes (1:1 INPUT:CHANNEL relationship)
    parameter DEPTH         = 16,               // entries in event FIFO
    parameter PBITS         = 4,                // bits for input prescaler (2-32)
    parameter EBITS         = 8,                // bits for event counter (2-31)

    // ** CSR **
    parameter CSR_ADDR      = 32,
    parameter CORE_INSTANCE = 32'h00000000      // 32-bit identifier to place in REG_CORE_INSTANCE field
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // timebase input
    input   wire    [63:0]          timebase_cnt,

    // event inputs
    input   wire    [INPUTS-1:0]    trigger,
    input   wire    [(INPUTS*META)-1:0] meta,
    
    // ** Register Bus **

    // command
    input   wire                    csr_cmd_valid,
    input   wire                    csr_cmd_write,
    input   wire    [CSR_ADDR-1:0]  csr_cmd_addr,
    input   wire    [31:0]          csr_cmd_data,

    // response
    output  reg                     csr_rsp_valid,
    output  reg                     csr_rsp_error,
    output  reg     [31:0]          csr_rsp_data,

    // interrupt
    output  reg                     csr_int
);

localparam  CORE_MAGIC          = 32'hfa2d8f2a; // lower 32 bits of md5sum of "dlsc_timer_capture"
localparam  CORE_VERSION        = 32'h20120607;
localparam  CORE_INTERFACE      = 32'h20120607;

`include "dlsc_clog2.vh"

localparam  IBITS               = 8;
localparam  FIFO_ADDR           = `dlsc_clog2(DEPTH);

integer i;
genvar j;

// ** Registers **

// 0x00: COMMON: Core magic (RO)
// 0x01: COMMON: Core version (RO)
// 0x02: COMMON: Core interface version (RO)
// 0x03: COMMON: Core instance (RO)
// 0x04: Control (RW)
//  [0]     : enable
// 0x05: Status (RO)
//  [15:0]  : channel states
// 0x06: Interrupt flags (RW; write 1 to clear)
//  [0]     : FIFO not empty
//  [1]     : FIFO half full
//  [2]     : FIFO full
//  [3]     : channel event counter overflow (any channel)
//  [31:16] : channel lost event (FIFO overflow or contention)
// 0x07: Interrupt select (RW)
// 0x08: FIFO count (RO)
// 0x09: FIFO: Event channel (RO)
//  [15:0]  : channel states at time of event
//  [19:16] : channel index
//  [31]    : FIFO empty
// 0x0A: FIFO: Event metadata (RO)
// 0x0B: FIFO: Event time low (RO)
// 0x0C: FIFO: Event time high (RO; pops FIFO)
// 0x10: channel 0 source (RW)
//  [7:0]   : source
//  [8]     : positive edge sensitive
//  [9]     : negative edge sensitive
// ..
// 0x1F: channel 15 source
// 0x20: channel 0 prescaler (RW)
// ..
// 0x2F: channel 15 prescaler (RW)
// 0x30: channel 0 event counter (RO; clear on read)
//  [30:0]  : counter
//  [31]    : overflow
// ..
// 0x3F: channel 15 event counter (RO; clear on read)

localparam  REG_CORE_MAGIC      = 6'h00,
            REG_CORE_VERSION    = 6'h01,
            REG_CORE_INTERFACE  = 6'h02,
            REG_CORE_INSTANCE   = 6'h03;

localparam  REG_CONTROL         = 6'h04,
            REG_STATUS          = 6'h05,
            REG_INT_FLAGS       = 6'h06,
            REG_INT_SELECT      = 6'h07,
            REG_FIFO_COUNT      = 6'h08,
            REG_FIFO_CHANNEL    = 6'h09,
            REG_FIFO_META       = 6'h0A,
            REG_FIFO_LOW        = 6'h0B,
            REG_FIFO_HIGH       = 6'h0C;

localparam  REG_SOURCE          = 6'h1Z,
            REG_PRESCALER       = 6'h2Z,
            REG_EVENT           = 6'h3Z;

wire [5:0]  csr_addr = csr_cmd_addr[7:2];

wire        set_fifo_not_empty;
wire        set_fifo_half_full;
wire        set_fifo_full;

wire [15:0] set_event_overflow;
wire [15:0] set_lost_event;

wire [15:0] channel_states;
wire [31:0] channel_source      [15:0];
wire [31:0] channel_prescaler   [15:0];
wire [31:0] channel_counter     [15:0];

reg         enabled;
reg  [31:0] int_flags;
reg  [31:0] int_select;

wire [31:0] fifo_count;
wire [31:0] fifo_channel;
wire [31:0] fifo_meta;
wire [31:0] fifo_low;
wire [31:0] fifo_high;

// Read mux

always @(posedge clk) begin
    if(rst || csr_rsp_valid) begin
        csr_rsp_valid       <= 1'b0;
        csr_rsp_error       <= 1'b0;
        csr_rsp_data        <= 0;
    end else if(csr_cmd_valid) begin
        csr_rsp_valid       <= 1'b1;
        csr_rsp_error       <= 1'b0;
        csr_rsp_data        <= 0;
        if(!csr_cmd_write) begin
            casez(csr_addr)
                REG_CORE_MAGIC:     csr_rsp_data        <= CORE_MAGIC;
                REG_CORE_VERSION:   csr_rsp_data        <= CORE_VERSION;
                REG_CORE_INTERFACE: csr_rsp_data        <= CORE_INTERFACE;
                REG_CORE_INSTANCE:  csr_rsp_data        <= CORE_INSTANCE;
                REG_CONTROL:        csr_rsp_data[0]     <= enabled;
                REG_STATUS:         csr_rsp_data[15:0]  <= channel_states;
                REG_INT_FLAGS:      csr_rsp_data        <= int_flags;
                REG_INT_SELECT:     csr_rsp_data        <= int_select;
                REG_FIFO_COUNT:     csr_rsp_data        <= fifo_count;
                REG_FIFO_CHANNEL:   csr_rsp_data        <= fifo_channel;
                REG_FIFO_META:      csr_rsp_data        <= fifo_meta;
                REG_FIFO_LOW:       csr_rsp_data        <= fifo_low;
                REG_FIFO_HIGH:      csr_rsp_data        <= fifo_high;
                REG_SOURCE:         csr_rsp_data        <= channel_source[csr_addr[3:0]];
                REG_PRESCALER:      csr_rsp_data        <= channel_prescaler[csr_addr[3:0]];
                REG_EVENT:          csr_rsp_data        <= channel_counter[csr_addr[3:0]];
                default:            csr_rsp_data        <= 0;
            endcase
        end
    end
end

// Control

always @(posedge clk) begin
    if(rst) begin
        enabled <= 1'b0;
    end else begin
        if(csr_cmd_valid && csr_cmd_write && csr_addr == REG_CONTROL) begin
            enabled <= csr_cmd_data[0];
        end
    end
end

// Interrupt Flags

reg  [31:0] next_int_flags;

always @* begin
    next_int_flags  = int_flags;
    
    if(csr_cmd_valid && csr_cmd_write && csr_addr == REG_INT_FLAGS) begin
        next_int_flags  = next_int_flags & ~csr_cmd_data;
    end
    
    if(set_fifo_not_empty)  next_int_flags[0]   = 1'b1;
    if(set_fifo_half_full)  next_int_flags[1]   = 1'b1;
    if(set_fifo_full)       next_int_flags[2]   = 1'b1;
    if(|set_event_overflow) next_int_flags[3]   = 1'b1;

    next_int_flags[31:16] = next_int_flags[31:16] | set_lost_event;
end

always @(posedge clk) begin
    if(rst) begin
        int_flags               <= 0;
        csr_int                 <= 1'b0;
    end else begin
        int_flags               <= 0;
        int_flags[3:0]          <= next_int_flags[3:0];
        int_flags[16+:CHANNELS] <= next_int_flags[16+:CHANNELS];
        csr_int                 <= |(int_flags & int_select);
    end
end

// Interrupt Select

always @(posedge clk) begin
    if(rst) begin
        int_select              <= 0;
    end else begin
        if(csr_cmd_valid && csr_cmd_write && csr_addr == REG_INT_SELECT) begin
            int_select              <= 0;
            int_select[3:0]         <= csr_cmd_data[3:0];
            int_select[16+:CHANNELS]<= csr_cmd_data[16+:CHANNELS];
        end
    end
end


// ** Channels **

// delay cnt by 1 cycle to match trigger input registering delay inside capture channels
reg [63:0] c1_cnt;
always @(posedge clk) begin
    c1_cnt <= timebase_cnt;
end

wire [15:0]     arb_ready;
wire [15:0]     arb_valid;
wire [63:0]     arb_time [15:0];
wire [CHANNELS-1:0] arb_chstate [15:0];
wire [META-1:0] arb_meta [15:0];

generate

for(j=0;j<CHANNELS;j=j+1) begin:GEN_CHANNELS

    dlsc_timer_capture_channel #(
        .INDEX              ( j ),
        .INPUTS             ( INPUTS ),
        .IBITS              ( IBITS ),
        .META               ( META ),
        .CHANNELS           ( CHANNELS ),
        .NOMUX              ( NOMUX ),
        .PBITS              ( PBITS ),
        .EBITS              ( EBITS ),
        .CSR_ADDR           ( CSR_ADDR )
    ) dlsc_timer_capture_channel (
        .clk                ( clk ),
        .rst                ( rst ),
        .cnt                ( c1_cnt ),
        .trigger            ( trigger ),
        .meta               ( meta ),
        .enabled            ( enabled ),
        .ch_out             ( channel_states[j] ),
        .ch_in              ( channel_states[CHANNELS-1:0] ),
        .fifo_ready         ( arb_ready[j] ),
        .fifo_valid         ( arb_valid[j] ),
        .fifo_cnt           ( arb_time[j] ),
        .fifo_chstate       ( arb_chstate[j] ),
        .fifo_meta          ( arb_meta[j] ),
        .set_event_overflow ( set_event_overflow[j] ),
        .set_lost_event     ( set_lost_event[j] ),
        .csr_cmd_valid      ( csr_cmd_valid ),
        .csr_cmd_write      ( csr_cmd_write ),
        .csr_cmd_addr       ( csr_cmd_addr ),
        .csr_cmd_data       ( csr_cmd_data ),
        .reg_source         ( channel_source[j] ),
        .reg_prescaler      ( channel_prescaler[j] ),
        .reg_event          ( channel_counter[j] )
    );

end

for(j=CHANNELS;j<16;j=j+1) begin:GEN_UNUSED_CHANNELS

    assign arb_valid[j]             = 1'b0;
    assign arb_time[j]              = 64'h0;
    assign arb_chstate[j]           = 0;
    assign arb_meta[j]              = 0;
    assign set_event_overflow[j]    = 1'b0;
    assign set_lost_event[j]        = 1'b0;
    assign channel_states[j]        = 1'b0;
    assign channel_source[j]        = 0;
    assign channel_prescaler[j]     = 0;
    assign channel_counter[j]       = 0;

end

endgenerate


// ** FIFO Arbiter **

wire        wr_almost_full;
wire        wr_full;
reg         wr_valid;
wire        wr_push     = wr_valid && !wr_full;

reg  [3:0]  wr_index;
reg  [63:0] wr_time;
reg  [CHANNELS-1:0] wr_chstate;
reg  [META-1:0] wr_meta;

reg       arb_set;
reg [3:0] arb_sel;

always @* begin
    arb_set     = 1'b0;
    arb_sel     = 0;
    arb_ready   = 0;
    if(!wr_valid || !wr_full) begin
        // priority encode; channel 0 is always highest priority
        for(i=CHANNELS-1;i>=0;i=i-1) begin
            if(arb_valid[i]) begin
/* verilator lint_off WIDTH */
                arb_set     = 1'b1;
                arb_sel     = i;
                arb_ready   = 1<<i;
/* verilator lint_on WIDTH */
            end
        end
    end
end

always @(posedge clk) begin
    if(arb_set) begin
        wr_index    <= arb_sel;
        wr_time     <= arb_time[arb_sel];
        wr_chstate  <= arb_chstate[arb_sel];
        wr_meta     <= arb_meta[arb_sel];
    end
end

always @(posedge clk) begin
    if(rst) begin
        wr_valid    <= 1'b0;
    end else begin
        if(wr_push) begin
            wr_valid    <= 1'b0;
        end
        if(arb_set) begin
            wr_valid    <= 1'b1;
        end
    end
end


// ** FIFO **

wire        rd_empty;
wire [FIFO_ADDR:0] rd_count;

reg         rd_pop;
always @(posedge clk) begin
    if(rst || !enabled) begin
        rd_pop  <= 1'b0;
    end else begin
        rd_pop  <= (!rd_empty && csr_cmd_valid && !csr_cmd_write && csr_addr == REG_FIFO_HIGH);
    end
end

wire [3:0]  rd_index;
wire [63:0] rd_time;
wire [CHANNELS-1:0] rd_chstate;
wire [META-1:0] rd_meta;

dlsc_fifo #(
    .ADDR           ( FIFO_ADDR ),
    .DATA           ( META + CHANNELS + 4 + 64 ),
    .ALMOST_FULL    ( (2**FIFO_ADDR)/2 ),
    .COUNT          ( 1 )
) dlsc_fifo (
    .clk            ( clk ),
    .rst            ( rst || !enabled ),
    .wr_push        ( wr_push ),
    .wr_data        ( { wr_meta, wr_chstate, wr_index, wr_time } ),
    .wr_full        ( wr_full ),
    .wr_almost_full ( wr_almost_full ),
    .wr_free        (  ),
    .rd_pop         ( rd_pop ),
    .rd_data        ( { rd_meta, rd_chstate, rd_index, rd_time } ),
    .rd_empty       ( rd_empty ),
    .rd_almost_empty (  ),
    .rd_count       ( rd_count )
);

assign fifo_count   = { {(31-FIFO_ADDR){1'b0}}, rd_count };

assign fifo_channel = rd_empty ? 32'h80000000 : { 12'd0, rd_index, {(16-CHANNELS){1'b0}}, rd_chstate };
assign fifo_meta    = rd_empty ? 32'h00000000 : { {(32-META){1'b0}} , rd_meta };
assign fifo_low     = rd_empty ? 32'h00000000 : rd_time[31:0];
assign fifo_high    = rd_empty ? 32'h00000000 : rd_time[63:32];

assign set_fifo_not_empty   = !rd_empty;
assign set_fifo_half_full   = wr_almost_full;
assign set_fifo_full        = wr_full;


endmodule

