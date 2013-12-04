// 
// Copyright (c) 2013, Daniel Strother < http://danstrother.com/ >
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
// Implements a 3x3 median filter using a pipelined version of Mahmoodi's algorithm.

module dlsc_median_3x3 #(
    parameter BITS      = 8     // bits for data
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // input
    // submit 1 whole column at a time
    input   wire                    in_valid,
    input   wire                    in_last,    // last pixel in row
    input   wire    [3*BITS-1:0]    in_data,

    // output
    // output is only produced once 3 columns are accumulated
    // pipeline delay from input to output is 11 cycles
    output  reg                     out_valid,
    output  reg                     out_last,
    output  reg     [  BITS-1:0]    out_data
);

// ** sort column **

wire [BITS-1:0] c3_k;
wire [BITS-1:0] c3_l;
wire [BITS-1:0] c3_m;

dlsc_median_3x3_slice #(
    .BITS       ( BITS )
) dlsc_median_3x3_slice_klm (
    .clk        ( clk ),
    .c0_data0   ( in_data[ 0*BITS +: BITS ] ),
    .c0_data1   ( in_data[ 1*BITS +: BITS ] ),
    .c0_data2   ( in_data[ 2*BITS +: BITS ] ),
    .c3_data0   ( c3_k ),
    .c3_data1   ( c3_l ),
    .c3_data2   ( c3_m )
);

// ** accumulate window of 3 sorted columns **

wire            c3_en;

dlsc_pipedelay #(
    .DELAY      ( 3-0 ),
    .DATA       ( 1 )
) dlsc_pipedelay_c0_c3 (
    .clk        ( clk ),
    .in_data    ( in_valid ),
    .out_data   ( c3_en )
);

reg  [BITS-1:0] c4_k;
reg  [BITS-1:0] c4_l;
reg  [BITS-1:0] c4_m;

reg  [BITS-1:0] c4_f;
reg  [BITS-1:0] c4_g;
reg  [BITS-1:0] c4_h;

reg  [BITS-1:0] c4_a;
reg  [BITS-1:0] c4_b;
reg  [BITS-1:0] c4_c;

always @(posedge clk) begin
    if(c3_en) begin
        { c4_a, c4_f, c4_k } <= { c4_f, c4_k, c3_k };
        { c4_b, c4_g, c4_l } <= { c4_g, c4_l, c3_l };
        { c4_c, c4_h, c4_m } <= { c4_h, c4_m, c3_m };
    end
end

// ** compute maximum of column minimums (maxmin) **

wire [BITS-1:0] c5_maxmin_f;

dlsc_compex #(
    .DATA       ( BITS ),
    .ID         ( 1 ),
    .PIPELINE   ( 0 )
) dlsc_compex_maxmin_c4 (
    .clk        ( clk ),
    .in_id0     ( 1'b0 ),
    .in_id1     ( 1'b0 ),
    .in_data0   ( c4_a ),
    .in_data1   ( c4_f ),
    .out_id0    (  ),
    .out_id1    (  ),
    .out_data0  (  ),
    .out_data1  ( c5_maxmin_f )
);

reg  [BITS-1:0] c5_k;

always @(posedge clk) begin
    c5_k <= c4_k;
end

wire [BITS-1:0] c7_maxmin;

dlsc_compex #(
    .DATA       ( BITS ),
    .ID         ( 1 ),
    .PIPELINE   ( 1 )
) dlsc_compex_maxmin_c5 (
    .clk        ( clk ),
    .in_id0     ( 1'b0 ),
    .in_id1     ( 1'b0 ),
    .in_data0   ( c5_maxmin_f ),
    .in_data1   ( c5_k ),
    .out_id0    (  ),
    .out_id1    (  ),
    .out_data0  (  ),
    .out_data1  ( c7_maxmin )
);

// ** compute minimum of column maximums (minmax) **

wire [BITS-1:0] c5_minmax_h;

dlsc_compex #(
    .DATA       ( BITS ),
    .ID         ( 1 ),
    .PIPELINE   ( 0 )
) dlsc_compex_minmax_c4 (
    .clk        ( clk ),
    .in_id0     ( 1'b0 ),
    .in_id1     ( 1'b0 ),
    .in_data0   ( c4_h ),
    .in_data1   ( c4_m ),
    .out_id0    (  ),
    .out_id1    (  ),
    .out_data0  ( c5_minmax_h ),
    .out_data1  (  )
);

reg  [BITS-1:0] c5_c;

always @(posedge clk) begin
    c5_c <= c4_c;
end

wire [BITS-1:0] c7_minmax;

dlsc_compex #(
    .DATA       ( BITS ),
    .ID         ( 1 ),
    .PIPELINE   ( 1 )
) dlsc_compex_minmax_c5 (
    .clk        ( clk ),
    .in_id0     ( 1'b0 ),
    .in_id1     ( 1'b0 ),
    .in_data0   ( c5_c ),
    .in_data1   ( c5_minmax_h ),
    .out_id0    (  ),
    .out_id1    (  ),
    .out_data0  ( c7_minmax ),
    .out_data1  (  )
);

// ** compute median of column medians (medmed) **

wire [BITS-1:0] c7_medmed;

dlsc_median_3x3_slice #(
    .BITS       ( BITS )
) dlsc_median_3x3_slice_medmed (
    .clk        ( clk ),
    .c0_data0   ( c4_b ),
    .c0_data1   ( c4_g ),
    .c0_data2   ( c4_l ),
    .c3_data0   (  ),
    .c3_data1   ( c7_medmed ),
    .c3_data2   (  )
);

// ** compute final median **

wire [BITS-1:0] c10_med;

dlsc_median_3x3_slice #(
    .BITS       ( BITS )
) dlsc_median_3x3_slice_med (
    .clk        ( clk ),
    .c0_data0   ( c7_maxmin ),
    .c0_data1   ( c7_medmed ),
    .c0_data2   ( c7_minmax ),
    .c3_data0   (  ),
    .c3_data1   ( c10_med ),
    .c3_data2   (  )
);

// ** output **

wire            c10_valid;
wire            c10_last;

dlsc_pipedelay_valid #(
    .DELAY      ( 10-0 ),
    .DATA       ( 1 )
) dlsc_pipedelay_valid (
    .clk        ( clk ),
    .rst        ( rst ),
    .in_valid   ( in_valid ),
    .in_data    ( in_last ),
    .out_valid  ( c10_valid ),
    .out_data   ( c10_last )
);

reg             c10_cnt;
reg             c10_primed;

always @(posedge clk) begin
    if(rst) begin
        {c10_primed,c10_cnt} <= 2'b00;
    end else if(c10_valid) begin
        if(c10_last) begin
            {c10_primed,c10_cnt} <= 2'b00;
        end else begin
            {c10_primed,c10_cnt} <= {c10_cnt,1'b1};
        end
    end
end

always @(posedge clk) begin
    if(rst) begin
        out_valid   <= 1'b0;
    end else begin
        out_valid   <= c10_valid && c10_primed;
    end
end

always @(posedge clk) begin
    out_last    <= c10_last;
    out_data    <= c10_med;
end

// ** simulation checks **

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @(posedge clk) begin
    if(!rst) begin
        if(c10_valid && c10_last && !c10_primed) begin
            `dlsc_warn("got last before completely primed; no last forwarded to output");
        end
    end
end

`include "dlsc_sim_bot.vh"
`endif

endmodule

