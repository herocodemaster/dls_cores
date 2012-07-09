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
// Programmable pulse cleaner.
//
// Inputs are synchronized by sync flops (if SYNC parameter is set) and filtered
// by glitch filters of depth FILTER (or not, if FILTER is 0).
//
// The timebase for the glitch filters is selectable via the Timebase-Filter
// field in REG_TIMEBASE.
//
// Once filtered, input events are detected. Events may be rising-edge, falling-
// edge, or both based on the settings in REG_CONTROL.
//
// When an event is detected, the output channel is deasserted. After a delay of
// REG_DELAY timebase cycles, the output is then asserted. The output remains
// asserted for REG_ACTIVE timebase cycles. If another event is detected before
// this interval expires, the output is immediately deasserted.
//
// The timebase for these delay counters is independently selectable via the
// Timebase-Counter field in REG_TIMEBASE.
//
// The initial assertion delay may be eliminated by setting REG_DELAY to 0. The
// entire engine may be bypassed by setting the Bypass flag in REG_CONTROL. The
// glitch filters are still active when bypassed.
//
// The outputs may optionally be inverted by setting the Invert flag in
// REG_CONTROL.

module dlsc_pulseclean #(
    parameter SYNC              = 1,            // include input synchronizers
    parameter FILTER            = 16,           // depth of input glitch-filter (0 to disable)
    parameter CHANNELS          = 1,            // channels to subject to cleaning
    parameter TIMEBASES         = 1,            // number of possible timebase sources
    parameter BITS              = 16,           // bits for delay/active counters
    
    // ** CSR **
    parameter CSR_ADDR          = 32,
    parameter CORE_INSTANCE     = 32'h00000000  // 32-bit identifier to place in REG_CORE_INSTANCE field
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // timebase input
    input   wire    [TIMEBASES-1:0] timebase_en,

    // pulse input
    input   wire    [CHANNELS-1:0]  in_pulse,

    // pulse output
    output  wire    [CHANNELS-1:0]  out_pulse,
    
    // ** Register Bus **

    // command
    input   wire                    csr_cmd_valid,
    input   wire                    csr_cmd_write,
    input   wire    [CSR_ADDR-1:0]  csr_cmd_addr,
    input   wire    [31:0]          csr_cmd_data,

    // response
    output  reg                     csr_rsp_valid,
    output  reg                     csr_rsp_error,
    output  reg     [31:0]          csr_rsp_data
);

`include "dlsc_clog2.vh"

localparam  CORE_MAGIC          = 32'h0f810b29; // lower 32 bits of md5sum of "dlsc_pulseclean"
localparam  CORE_VERSION        = 32'h20120708;
localparam  CORE_INTERFACE      = 32'h20120708;

localparam  TB                  = `dlsc_clog2(TIMEBASES);   // bits to select timebase

integer i;
genvar j;

// ** Registers **
// 0x4: Control (RW)
//  [0]     : bypass
//  [1]     : invert output
//  [2]     : rising-edge sensitive
//  [3]     : falling-edge sensitive
// 0x5: Timebase select (RW)
//  [7:0]   : timebase select for counters
//  [8]     : use internal timebase for counters
//  [23:16] : timebase select for filters
//  [24]    : use internal timebase for filters
// 0x6: Delay time (RW)
// 0x7: Active time (RW)

localparam  REG_CORE_MAGIC      = 3'h0,
            REG_CORE_VERSION    = 3'h1,
            REG_CORE_INTERFACE  = 3'h2,
            REG_CORE_INSTANCE   = 3'h3;

localparam  REG_CONTROL         = 3'h4,
            REG_TIMEBASE        = 3'h5,
            REG_DELAY           = 3'h6,
            REG_ACTIVE          = 3'h7;

wire [2:0]          csr_addr        = csr_cmd_addr[4:2];

reg                 bypass;
reg                 invert;
reg                 rise_sensitive;
reg                 fall_sensitive;

wire [31:0]         csr_control     = {28'd0,fall_sensitive,rise_sensitive,invert,bypass};

reg  [TB-1:0]       timebase_sel_cntr;
reg                 timebase_int_cntr;

reg  [TB-1:0]       timebase_sel_fltr;
reg                 timebase_int_fltr;

wire [31:0]         csr_timebase    = {         7'd0,    timebase_int_fltr,
                                        {(8-TB){1'b0}} , timebase_sel_fltr,
                                                7'd0,    timebase_int_cntr,
                                        {(8-TB){1'b0}} , timebase_sel_cntr };

reg  [BITS-1:0]     time_delay;
wire                time_delay_zero = (time_delay == 0);

reg  [BITS-1:0]     time_active;


// ** register write **

always @(posedge clk) begin
    if(rst) begin
        bypass          <= 1'b1;
        invert          <= 1'b0;
        rise_sensitive  <= 1'b0;
        fall_sensitive  <= 1'b0;
        timebase_sel_cntr <= 0;
        timebase_int_cntr <= 1'b1;
        timebase_sel_fltr <= 0;
        timebase_int_fltr <= 1'b1;
        time_delay      <= 1;
        time_active     <= 1;
    end else if(csr_cmd_valid && csr_cmd_write) begin
        if(csr_addr == REG_CONTROL) begin
            bypass          <= csr_cmd_data[0];
            invert          <= csr_cmd_data[1];
            rise_sensitive  <= csr_cmd_data[2];
            fall_sensitive  <= csr_cmd_data[3];
        end
        if(csr_addr == REG_TIMEBASE) begin
            timebase_sel_cntr <= csr_cmd_data[  0 +: TB ];
            timebase_int_cntr <= csr_cmd_data[  8 ];
            timebase_sel_fltr <= csr_cmd_data[ 16 +: TB ];
            timebase_int_fltr <= csr_cmd_data[ 24 ];
        end
        if(csr_addr == REG_DELAY) begin
            time_delay      <= csr_cmd_data[BITS-1:0];
        end
        if(csr_addr == REG_ACTIVE) begin
            time_active     <= csr_cmd_data[BITS-1:0];
        end
    end
end


// ** register read **

always @(posedge clk) begin
    csr_rsp_valid   <= 1'b0;
    csr_rsp_error   <= 1'b0;
    csr_rsp_data    <= 0;
    if(!rst && csr_cmd_valid) begin
        csr_rsp_valid   <= 1'b1;
        if(!csr_cmd_write) begin
            // read
            case(csr_addr)
                REG_CORE_MAGIC:     csr_rsp_data            <= CORE_MAGIC;
                REG_CORE_VERSION:   csr_rsp_data            <= CORE_VERSION;
                REG_CORE_INTERFACE: csr_rsp_data            <= CORE_INTERFACE;
                REG_CORE_INSTANCE:  csr_rsp_data            <= CORE_INSTANCE;
                REG_CONTROL:        csr_rsp_data            <= csr_control;
                REG_TIMEBASE:       csr_rsp_data            <= csr_timebase;
                REG_DELAY:          csr_rsp_data[BITS-1:0]  <= time_delay;
                REG_ACTIVE:         csr_rsp_data[BITS-1:0]  <= time_active;
                default:            csr_rsp_data            <= 0;
            endcase
        end
    end
end


// ** clock enable mux **

wire [(2**TB)-1:0]  clk_en_mux      = { {((2**TB)-TIMEBASES){1'b0}} , timebase_en };

reg                 clk_en;
reg                 clk_en_fltr;

always @(posedge clk) begin
    if(rst) begin
        clk_en      <= 1'b0;
        clk_en_fltr <= 1'b0;
    end else begin
        clk_en      <= timebase_int_cntr ? 1'b1 : clk_en_mux[timebase_sel_cntr];
        clk_en_fltr <= timebase_int_fltr ? 1'b1 : clk_en_mux[timebase_sel_fltr];
    end
end


// ** input filtering **

wire [CHANNELS-1:0] in_sync;

dlsc_glitchfilter #(
    .SYNC   ( SYNC ),
    .DEPTH  ( FILTER )
) dlsc_glitchfilter[CHANNELS-1:0] (
    .clk    ( clk ),
    .clk_en ( clk_en_fltr ),
    .rst    ( rst ),
    .in     ( in_pulse ),
    .out    ( in_sync )
);


// ** event detection **

reg  [CHANNELS-1:0] in_sync_prev;

always @(posedge clk) begin
    in_sync_prev    <= in_sync;
end

reg  [CHANNELS-1:0] in_event;

always @* begin
    in_event    = 0;
    for(i=0;i<CHANNELS;i=i+1) begin
        if( (rise_sensitive &&  in_sync[i] && !in_sync_prev[i]) ||
            (fall_sensitive && !in_sync[i] &&  in_sync_prev[i]) )
        begin
            in_event[i] = 1'b1;
        end
    end
end


// ** filters **

wire [CHANNELS-1:0] out_pre;

localparam  ST_DELAY    = 2'b00,
            ST_ACTIVE   = 2'b01,
            ST_IDLE     = 2'b10;

generate
for(j=0;j<CHANNELS;j=j+1) begin:GEN_CHANNELS

    reg  [BITS-1:0]     cnt;
    wire [BITS-1:0]     cnt_p1      = cnt + 1;

    reg  [1:0]          st;

    assign              out_pre[j]  = (st == ST_ACTIVE);

    wire                cnt_last    = (cnt == 1);

    always @(posedge clk) begin
        if(rst || bypass || in_event[j]) begin
            st          <= time_delay_zero ? ST_ACTIVE   : ST_DELAY;
            cnt         <= time_delay_zero ? time_active : time_delay;
        end else if(clk_en) begin
            if(!cnt_last) begin
                cnt         <= cnt - 1;
            end else begin
                if(st == ST_DELAY) begin
                    st          <= ST_ACTIVE;
                    cnt         <= time_active;
                end
                if(st == ST_ACTIVE) begin
                    st          <= ST_IDLE;
                end
            end
        end
    end

end
endgenerate


// ** output **

always @(posedge clk) begin
    if(rst) begin
        out_pulse   <= 0;
    end else begin
        out_pulse   <= {CHANNELS{invert}} ^ (bypass ? in_sync : out_pre);
    end
end

endmodule

