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
// Master timebase with fractional-n clock prescaler, master counter, and
// multiple divided clock enable outputs.
//
// External control firmware can implement a simple phase-locked-loop that
// fine-tunes the prescaler (via freq_in) to keep the timebase in sync with
// an external reference.
//
// Large changes to the timebase can be made via the adj_en/value inputs.
//
// Note that all prescalers/dividers are free-running; adj_value has no control
// over them. If you wish to maintain alignment between the timebase and the
// clk_en outputs, then you should only apply adjustment values that are
// multiples of the least-common-multiple of all OUTPUT_DIV values.
//
// E.g. with an effective CNT_FREQ of 1 GHz (e.g. CNT_RATE of 10 MHz and CNT_INC
// of 100) and clk_en_out rates of 10 MHz, 1 MHz, 1 KHz and 1 Hz, then you should
// only apply adj_values that are a multiple of 1 GHz / 1 Hz = 1,000,000,000.

module dlsc_timebase_core #(

//  parameter FREQ_IN       = 100000000,                // nominal clk input frequency (in Hz)

    parameter CNT_RATE      = 10000000,                 // increment rate for master counter (in Hz)
    parameter CNT_INC       = (1000000000/CNT_RATE),    // increment amount for master counter

    parameter CNTB          = 64,                       // bits for master counter
    parameter DIVB          = 32,                       // bits for fractional divider (enough bits for max FREQ_IN + sign bit)

    parameter OUTPUTS       = 1,                        // number of clk_en outputs (at least 1)
    parameter OUTPUT_DIV    = {OUTPUTS{32'd1}}          // integer divider for each output (divides down from CNT_RATE)
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // enable outputs
    output  wire    [OUTPUTS-1:0]   clk_en_out,

    // status
    output  wire                    stopped,            // flag that indicates timebase is stopped (in reset)
    output  wire                    adjusting,          // flag indicating counter is about to be adjusted

    // master counter output
    output  wire    [CNTB-1:0]      cnt,                // unsigned master counter value
    output  wire                    cnt_wrapped,        // counter wrapped across 0 (typically overflow, but could also be underflow from negative adj_value)

    // master counter adjust input
    input   wire                    adj_en,
    input   wire    [CNTB-1:0]      adj_value,          // signed adjustment value

    // fractional divider control
    input   wire    [DIVB-1:0]      freq_in             // actual input frequency (in Hz; must be > CNT_RATE)
);

`include "dlsc_synthesis.vh"

integer i;
genvar j;


// ** divider **

reg  [DIVB-1:0] divcnt;
wire            c0_cnt_en       = !divcnt[DIVB-1];

always @(posedge clk) begin
    if(rst) begin
        divcnt          <= 0;
    end else begin
/* verilator lint_off WIDTH */
        divcnt          <= divcnt + CNT_RATE - (c0_cnt_en ? freq_in : 0);
/* verilator lint_on WIDTH */
    end
end

`DLSC_FANOUT_REG reg c1_cnt_en;

always @(posedge clk) begin
    if(rst) begin
        c1_cnt_en       <= 1'b0;
    end else begin
        c1_cnt_en       <= c0_cnt_en;
    end
end


// ** adjuster **

reg             c2_adj_en;
reg  [CNTB-1:0] c2_adj;

always @(posedge clk) begin
    if(rst) begin
        c2_adj_en       <= 1'b0;
        c2_adj          <= 0;
    end else begin
        c2_adj_en       <= adj_en;
/* verilator lint_off WIDTH */
        c2_adj          <= (c1_cnt_en ? CNT_INC : 0) + (adj_en ? adj_value : 0);
/* verilator lint_on WIDTH */
    end
end


// ** counter **

reg  [CNTB-1:0] c3_cnt;
reg             c3_cnt_wrapped;

always @(posedge clk) begin
    if(rst) begin
        { c3_cnt_wrapped, c3_cnt } <= 0;
    end else begin
        // cnt is unsigned; adj is signed; carry/borrow indicates overflow/underflow
        { c3_cnt_wrapped, c3_cnt } <= { 1'b0, c3_cnt } + { c2_adj[CNTB-1], c2_adj };
    end
end


// ** output dividers **

wire [OUTPUTS-1:0] c2_clk_en;

generate
for(j=0;j<OUTPUTS;j=j+1) begin:GEN_OUTPUT_DIV

    integer od_cnt;
    reg     od_clk_en;

    assign c2_clk_en[j] = od_clk_en;

    always @(posedge clk) begin
        if(rst) begin
            od_cnt      <= 0;
            od_clk_en   <= 1'b0;
        end else begin
            od_clk_en   <= 1'b0;
            if(c1_cnt_en) begin
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


// ** buffer outputs **

`DLSC_FANOUT_REG    reg  [CNTB-1:0]     c4_cnt;
                    reg                 c4_cnt_wrapped;

`DLSC_FANOUT_REG    reg  [OUTPUTS-1:0]  c3_clk_en;
                    reg                 c3_stopped;
                    reg                 c3_adj_en;

always @(posedge clk) begin
    if(rst) begin
        c4_cnt          <= 0;
        c4_cnt_wrapped  <= 1'b0;
        c3_clk_en       <= 0;
        c3_stopped      <= 1'b1;
        c3_adj_en       <= 1'b0;
    end else begin
        c4_cnt          <= c3_cnt;
        c4_cnt_wrapped  <= c3_cnt_wrapped;
        c3_clk_en       <= c2_clk_en;
        if(c2_clk_en[0]) begin
            c3_stopped      <= 1'b0;
        end
        c3_adj_en       <= c2_adj_en;
    end
end

assign clk_en_out   = c3_clk_en;        // enables assert 1 cycle before count changes

assign stopped      = c3_stopped;
assign adjusting    = c3_adj_en;

assign cnt          = c4_cnt;
assign cnt_wrapped  = c4_cnt_wrapped;

endmodule

