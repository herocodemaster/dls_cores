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
//
// Master timebase with fractional counter and multiple divided clock enable
// outputs.
//
// External control firmware can implement a simple phase-locked-loop that
// fine-tunes the count rate (via period_in) to keep the timebase in sync with
// an external reference.
//
// Large changes to the timebase can be made via the adj_en/value inputs.
//
// Note that all prescalers/dividers are free-running; adj_value has no control
// over them. If you wish to maintain alignment between the timebase and the
// clk_en outputs, then you should only apply adjustment values that are
// multiples of the least-common-multiple of all OUTPUT_DIV values.

module dlsc_timebase_core #(
    parameter CNTB          = 64,                       // bits for master counter
    parameter PERB          = 8,                        // bits to specify input period
    parameter SUBB          = (32-PERB),                // bits to specify fractional input period

    parameter OUTPUTS       = 1,                        // number of clk_en outputs (at least 1)
    parameter OUTPUT_DIV    = {OUTPUTS{32'd1}}          // integer divider for each output (divides down from cfg_period_out)
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // timebase output
    output  wire    [OUTPUTS-1:0]   timebase_en,
    output  wire    [CNTB-1:0]      timebase_cnt,       // unsigned master counter value

    // configuration
    input   wire    [PERB+SUBB-1:0] cfg_period_in,      // period of input clock
    input   wire    [PERB+SUBB-1:0] cfg_period_out,     // period of output clock
    input   wire                    cfg_adj_en,         // enable adjust operation
    input   wire    [CNTB-1:0]      cfg_adj_value,      // signed adjustment value

    // status
    output  wire                    stopped,            // flag that indicates timebase is stopped (in reset)
    output  wire                    adjusting,          // flag indicating counter is about to be adjusted
    output  wire                    wrapped             // counter overflowed
);

`include "dlsc_util.vh"
`include "dlsc_synthesis.vh"

integer i;
genvar j;

localparam  BITS        = CNTB+SUBB;            // bits for master counter
localparam  STGB        = 32;                   // bits per adder stage
localparam  STAGES      = (BITS+STGB-1)/STGB;   // number of adder stages required

localparam  CA0         = STAGES;               // ca0 is output of adj_period adder
localparam  CB0         = CA0 + STAGES;         // cb0 is output of master counter

// delayed valids
reg  [CB0:1] valids_r;
wire [CB0:0] valids = {valids_r,1'b1};
reg  [CB0:1] adj_en_r;
wire [CB0:0] adj_en = {adj_en_r,cfg_adj_en};
always @(posedge clk) begin
    if(rst) begin
        valids_r    <= 0;
        adj_en_r    <= 0;
    end else begin
        valids_r    <= valids[CB0-1:0];
        adj_en_r    <= adj_en[CB0-1:0];
    end
end


// ** add adj_value to period_in **

// inputs
wire [BITS-1:0] pad_period_in   = { {(CNTB-PERB){1'b0}}, cfg_period_in };
wire [BITS-1:0] pad_adj_value   = { cfg_adj_value, {SUBB{1'b0}} };

// outputs
// cycle: STAGES (minimum: c1)
wire [BITS-1:0] sum_period_adj;

// carry between stages
wire [STAGES:0] sum_carrys;
assign sum_carrys[0] = 1'b0;

`define stgb ( (j==(STAGES-1)) ? (BITS-((STAGES-1)*STGB)) : STGB )

generate
for(j=0;j<STAGES;j=j+1) begin:GEN_ADJ_STAGES

    // delay inputs
    wire [`stgb-1:0] period;
    wire [`stgb-1:0] adj;

    dlsc_pipedelay #(
        .DATA       ( 2*`stgb ),
        .DELAY      ( j )
    ) dlsc_pipedelay_inputs (
        .clk        ( clk ),
        .in_data    ( { pad_period_in[ j*STGB +: `stgb ] , pad_adj_value[ j*STGB +: `stgb ] } ),
        .out_data   ( { period, adj } )
    );

    // add
    reg [`stgb  :0] sum;
    always @(posedge clk) begin
        sum     <= {1'b0,period} + ( adj_en[j] ? {1'b0,adj} : 0 ) + {{(`stgb){1'b0}},sum_carrys[j]};
    end
    assign sum_carrys[j+1] = sum[`stgb];

    // delay output
    dlsc_pipedelay #(
        .DATA       ( `stgb ),
        .DELAY      ( CA0-1-j )
    ) dlsc_pipedelay_output (
        .clk        ( clk ),
        .in_data    ( sum[`stgb-1:0] ),
        .out_data   ( sum_period_adj[ j*STGB +: `stgb ] )
    );

end
endgenerate


// ** add period_adj to counter **

// counter output
// cycle: 2*STAGES (minimum: c2)
wire [BITS:0] master_cnt_pre;

// carry between stages
wire [STAGES:0] cnt_carrys;
assign cnt_carrys[0] = 1'b0;
assign master_cnt_pre[BITS] = cnt_carrys[STAGES];

generate
for(j=0;j<STAGES;j=j+1) begin:GEN_CNT_STAGES

    // delay input
    wire [`stgb-1:0] period_adj;

    dlsc_pipedelay #(
        .DATA       ( `stgb ),
        .DELAY      ( j )
    ) dlsc_pipedelay_input (
        .clk        ( clk ),
        .in_data    ( sum_period_adj[ j*STGB +: `stgb ] ),
        .out_data   ( period_adj )
    );

    // add
    reg [`stgb  :0] sum;
    always @(posedge clk) begin
        if(rst) begin
            sum     <= 0;
        end else if(valids[CA0+j]) begin
            sum     <= {1'b0,sum[`stgb-1:0]} + {1'b0,period_adj} + {{(`stgb){1'b0}},cnt_carrys[j]};
        end
    end
    assign cnt_carrys[j+1] = sum[`stgb];

    // delay output
    dlsc_pipedelay #(
        .DATA       ( `stgb ),
        .DELAY      ( CB0-CA0-1-j )
    ) dlsc_pipedelay_output (
        .clk        ( clk ),
        .in_data    ( sum[`stgb-1:0] ),
        .out_data   ( master_cnt_pre[ j*STGB +: `stgb ] )
    );

end
endgenerate

`undef stgb


// ** master output divider **

// delay inputs so period changes take effect on the divider and the master
// counter at the same time

wire [PERB+SUBB-1:0] ca0_period_in;
wire [PERB+SUBB-1:0] ca0_period_out;

dlsc_pipedelay #(
    .DATA       ( 2*(PERB+SUBB) ),
    .DELAY      ( CA0  )
) dlsc_pipedelay_periods (
    .clk        ( clk ),
    .in_data    ( {cfg_period_in,cfg_period_out} ),
    .out_data   ( {ca0_period_in,ca0_period_out} )
);

localparam DIVB = PERB+SUBB+1;

reg  [DIVB-1:0]     div_cnt;
wire                ca0_cnt_en  = !div_cnt[DIVB-1];
`DLSC_FANOUT_REG reg ca1_cnt_en;

always @(posedge clk) begin
    if(!valids[CA0]) begin
        div_cnt     <= 0;
        ca1_cnt_en  <= 1'b0;
    end else begin
        div_cnt     <= div_cnt + {1'b0,ca0_period_in} - (ca0_cnt_en ? {1'b0,ca0_period_out} : 0);
        ca1_cnt_en  <= ca0_cnt_en;
    end
end


// ** secondary output dividers **

wire [OUTPUTS-1:0] ca2_clk_en;

generate
for(j=0;j<OUTPUTS;j=j+1) begin:GEN_OUTPUT_DIV

    integer od_cnt;
    reg     od_clk_en;

    assign  ca2_clk_en[j]   = od_clk_en;

    always @(posedge clk) begin
        if(!valids[CA0+1]) begin
            od_cnt      <= 0;
            od_clk_en   <= 1'b0;
        end else begin
            od_clk_en   <= 1'b0;
            if(ca1_cnt_en) begin
                if(od_cnt == 0) begin
                    od_clk_en   <= 1'b1;
                    od_cnt      <= (OUTPUT_DIV[ j*32 +: 32 ] - 1);
                end else begin
                    od_cnt      <= od_cnt - 1;
                end
            end
        end
    end

end
endgenerate

// delay to match counter

wire [OUTPUTS-1:0] cb0_clk_en;

dlsc_pipedelay_rst #(
    .DATA       ( OUTPUTS ),
    .RESET      ( {OUTPUTS{1'b0}} ),
    .DELAY      ( CB0 - (CA0+2) )
) dlsc_pipedelay_rst_clk_en (
    .clk        ( clk ),
    .rst        ( rst ),
    .in_data    ( ca2_clk_en ),
    .out_data   ( cb0_clk_en )
);


// ** buffer outputs **

wire            cb0_valid       = valids[CB0];
wire            cb0_adj_en      = adj_en[CB0];
wire [CNTB-1:0] cb0_cnt         = master_cnt_pre[BITS-1:SUBB];
wire            cb0_cnt_wrapped = master_cnt_pre[BITS];

`DLSC_FANOUT_REG    reg  [OUTPUTS-1:0]  cb1_clk_en;
                    reg                 cb1_adj_en;
                    reg                 cb1_stopped;
                    reg  [CNTB-1:0]     cb1_cnt;
                    reg                 cb1_cnt_wrapped;

`DLSC_FANOUT_REG    reg  [CNTB-1:0]     cb2_cnt;
                    reg                 cb2_cnt_wrapped;

always @(posedge clk) begin
    if(rst) begin
        cb1_stopped     <= 1'b1;
        cb1_clk_en      <= 0;
        cb1_adj_en      <= 1'b0;
        cb1_cnt         <= 0;
        cb1_cnt_wrapped <= 1'b0;
        cb2_cnt         <= 0;
        cb2_cnt_wrapped <= 1'b0;
    end else if(cb0_valid) begin
        cb1_stopped     <= 1'b0;
        cb1_clk_en      <= cb0_clk_en;
        cb1_adj_en      <= cb0_adj_en;
        cb1_cnt         <= cb0_cnt;
        cb1_cnt_wrapped <= cb0_cnt_wrapped;
        cb2_cnt         <= cb1_cnt;
        cb2_cnt_wrapped <= cb1_cnt_wrapped;
    end
end

assign timebase_en  = cb1_clk_en;        // enables assert 1 cycle before count changes

assign stopped      = cb1_stopped;
assign adjusting    = cb1_adj_en;

assign timebase_cnt = cb2_cnt;
assign wrapped      = cb2_cnt_wrapped;


endmodule

