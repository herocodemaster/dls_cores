// 
// Copyright (c) 2011, Daniel Strother < http://danstrother.com/ >
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
// Computes the sum-of-absolute-differences values over a sliding window at a
// fixed disparity. Can process multiple rows in parallel (and will share
// significant logic resources between those rows).
//
// Some code from the C reference model:
//
// // process one disparity level at a time
// for(int d=0;d<DISPARITIES;++d) {
//     int sad_accum = 0;
//     sad_delay.clear();
//     // process whole row at this disparity
//     for(int x=DISPARITIES-1;x<il.cols;++x) {
//         // sum column
//         int sad = 0;
//         for(int ys=0;ys<SAD;++ys)
//             sad += abs((int)(rowsl[ys][x]) - (int)(rowsr[ys][x-d]));
//         
//         // accumulate window
//         sad_accum += sad;
//         sad_delay.push_back(sad);
// 
//         // once window is filled, produce output
//         if(sad_delay.size()==SAD) {
// 
//             // ** keep track of best sad **
//             // ...snip...
// 
//             // ** keep track of adjacent sads **
//             // ...snip...
// 
//             // subtract column sums falling outside of window
//             sad_accum -= sad_delay.front(); sad_delay.pop_front();
//         }
//     } // for(x..
// } // for(d..

module dlsc_stereobm_pipe #(
    parameter MULT_R        = 1,
    parameter SAD           = 9,    // size of comparison window
    parameter DATA          = 9,    // width of input image data
    parameter SAD_BITS      = 16,   // width of SAD output data
    parameter PIPELINE_IN   = 0,    // enable pipeline register on input to pipe (needed by Virtex-6)
    // derived parameters; don't touch
    parameter SAD_R         = (SAD+MULT_R-1),
    parameter SAD_BITS_R    = (SAD_BITS*MULT_R)
) (
    input   wire                        clk,
    input   wire                        rst,

    // from row buffers
    input   wire                        in_right_valid, // asserted one cycle before in_right is valid
    input   wire                        in_valid,       // asserted one cycle before in_left is valid
    input   wire                        in_first,
    input   wire    [(DATA*SAD_R)-1:0]  in_left,
    input   wire    [(DATA*SAD_R)-1:0]  in_right,

    // to next parallel pipe
    output  reg     [(DATA*SAD_R)-1:0]  cascade_right,

    // output to disparity comparator
    output  wire                        out_valid,
    output  wire    [ SAD_BITS_R-1:0]   out_sad
);

`include "dlsc_synthesis.vh"
`include "dlsc_clog2.vh"

localparam SUM_BITS = DATA + `dlsc_clog2(SAD);      // width of data after column SAD

// extra registering on _valid inputs
`DLSC_KEEP_REG reg c0_right_valid;
`DLSC_KEEP_REG reg c0_valid;
wire                    c0_first  = in_first;
wire [(DATA*SAD_R)-1:0] c0_left   = in_left;
wire [(DATA*SAD_R)-1:0] c0_right  = in_right;

always @(posedge clk) begin
    if(rst) begin
        c0_right_valid  <= 1'b0;
        c0_valid        <= 1'b0;
    end else begin
        c0_right_valid  <= in_right_valid;
        c0_valid        <= in_valid;
    end
end

always @(posedge clk) begin
    if(c0_right_valid) begin
        cascade_right <= c0_right;
    end
end

// optional pipeline register stage
wire                  c1_valid;
wire                  c1_first;
wire [(DATA*SAD_R)-1:0] c1_left;
wire [(DATA*SAD_R)-1:0] c1_right;

generate if(!PIPELINE_IN) begin:GEN_NOPIPE

    assign c1_valid = c0_valid;
    assign c1_first = c0_first;
    assign c1_left  = c0_left;
    assign c1_right = c0_right;

end else begin:GEN_PIPE

    `DLSC_PIPE_REG reg                    c1r_valid;
    `DLSC_PIPE_REG reg                    c1r_first;
    `DLSC_PIPE_REG reg [(DATA*SAD_R)-1:0] c1r_left;

    always @(posedge clk) begin
        if(rst) begin
            c1r_valid   <= 1'b0;
        end else begin
            c1r_valid   <= c0_valid;
        end
    end

    always @(posedge clk) begin
        c1r_first   <= c0_first;
        c1r_left    <= c0_left;
    end

    assign c1_valid = c1r_valid;
    assign c1_first = c1r_first;
    assign c1_left  = c1r_left;
    assign c1_right = cascade_right;

end endgenerate


// compute Absolute Differences
wire                    c2_valid;
wire                    c2_first;
wire [(DATA*SAD_R)-1:0] c2_data;

dlsc_absdiff #(
    .WIDTH  ( DATA ),
    .META   ( 1 )
) dlsc_absdiff_inst0 (
    .clk        ( clk ),
    .rst        ( rst ),
    .in_valid   ( c1_valid ),
    .in_meta    ( c1_first ),
    .in0        ( c1_left [ (0*DATA) +: DATA ] ),
    .in1        ( c1_right[ (0*DATA) +: DATA ] ),
    .out_valid  ( c2_valid ),
    .out_meta   ( c2_first ),
    .out        ( c2_data [ (0*DATA) +: DATA ] )
);
generate
    genvar j;
    for(j=1;j<SAD_R;j=j+1) begin:GEN_ABSDIFF
        dlsc_absdiff #(
            .WIDTH  ( DATA ),
            .META   ( 1 )
        ) dlsc_absdiff_inst (
            .clk        ( clk ),
            .rst        ( rst ),
            .in_valid   ( c1_valid ),
            .in_meta    ( 1'b0 ),
            .in0        ( c1_left [ (j*DATA) +: DATA ] ),
            .in1        ( c1_right[ (j*DATA) +: DATA ] ),
            .out_valid  (  ),
            .out_meta   (  ),
            .out        ( c2_data [ (j*DATA) +: DATA ] )
        );
    end
endgenerate

// compute Sum of Absolute Differences for column
wire                    c3_valid;
wire                    c3_first;
wire [(SUM_BITS*MULT_R)-1:0] c3_data;

dlsc_stereobm_pipe_adder #(
    .DATA       ( DATA ),
    .SUM_BITS   ( SUM_BITS ),
    .SAD        ( SAD ),
    .MULT_R     ( MULT_R ),
    .META       ( 1 )
) dlsc_stereobm_pipe_adder_inst (
    .clk        ( clk ),
    .rst        ( rst ),
    .in_valid   ( c2_valid ),
    .in_meta    ( c2_first ),
    .in_data    ( c2_data ),
    .out_valid  ( c3_valid ),
    .out_meta   ( c3_first ),
    .out_data   ( c3_data )
);

// compute Sum of Absolute Differences for window

dlsc_stereobm_pipe_accumulator #(
    .IN_BITS    ( SUM_BITS ),
    .OUT_BITS   ( SAD_BITS ),
    .SAD        ( SAD ),
    .MULT_R     ( MULT_R )
) dlsc_stereobm_pipe_accumulator_inst (
    .clk        ( clk ),
    .rst        ( rst ),
    .in_valid   ( c3_valid ),
    .in_first   ( c3_first ),
    .in_sad     ( c3_data ),
    .out_valid  ( out_valid ),
    .out_sad    ( out_sad )
);


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"
integer valid_cnt;
integer cycle_cnt;
always @(posedge clk) begin
    if(rst) begin
        valid_cnt   <= 0;
        cycle_cnt   <= 0;
    end else begin
        cycle_cnt   <= cycle_cnt + 1;
        if(c0_valid) begin
            valid_cnt   <= valid_cnt + 1;
        end
    end
end

task report;
begin
    `dlsc_info("pipeline utilization: %0d%% (%0d/%0d)",((valid_cnt*100)/cycle_cnt),valid_cnt,cycle_cnt);
    dlsc_stereobm_pipe_adder_inst.report;
end
endtask
`include "dlsc_sim_bot.vh"
`endif

endmodule

