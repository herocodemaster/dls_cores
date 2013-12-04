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
// 3 input sorter for median_3x3.
// Resembles dlsc_sortnet_3, but without as much pipelining.

module dlsc_median_3x3_slice #(
    parameter BITS      = 8     // bits for data
) (
    // system
    input   wire                    clk,

    // input (unsorted)
    input   wire    [BITS-1:0]      c0_data0,
    input   wire    [BITS-1:0]      c0_data1,
    input   wire    [BITS-1:0]      c0_data2,

    // output (sorted)
    output  wire    [BITS-1:0]      c3_data0,   // min
    output  wire    [BITS-1:0]      c3_data1,   // med
    output  wire    [BITS-1:0]      c3_data2    // max
);

`include "dlsc_synthesis.vh"

// level 0

                wire [BITS-1:0] c1_data0;
                wire [BITS-1:0] c1_data1;
`DLSC_PIPE_REG  reg  [BITS-1:0] c1_data2;

always @(posedge clk) begin
    c1_data2 <= c0_data2;
end

dlsc_compex #(
    .DATA       ( BITS ),
    .ID         ( 1 ),
    .PIPELINE   ( 0 )
) dlsc_compex_c0 (
    .clk        ( clk ),
    .in_id0     ( 1'b0 ),
    .in_id1     ( 1'b0 ),
    .in_data0   ( c0_data0 ),
    .in_data1   ( c0_data1 ),
    .out_id0    (  ),
    .out_id1    (  ),
    .out_data0  ( c1_data0 ),
    .out_data1  ( c1_data1 )
);

// level 1

`DLSC_PIPE_REG  reg  [BITS-1:0] c2_data0;
                wire [BITS-1:0] c2_data1;
                wire [BITS-1:0] c2_data2;

always @(posedge clk) begin
    c2_data0 <= c1_data0;
end

dlsc_compex #(
    .DATA       ( BITS ),
    .ID         ( 1 ),
    .PIPELINE   ( 0 )
) dlsc_compex_c1 (
    .clk        ( clk ),
    .in_id0     ( 1'b0 ),
    .in_id1     ( 1'b0 ),
    .in_data0   ( c1_data1 ),
    .in_data1   ( c1_data2 ),
    .out_id0    (  ),
    .out_id1    (  ),
    .out_data0  ( c2_data1 ),
    .out_data1  ( c2_data2 )
);

// level 2

`DLSC_PIPE_REG  reg  [BITS-1:0] c3_data2_r;

always @(posedge clk) begin
    c3_data2_r <= c2_data2;
end

dlsc_compex #(
    .DATA       ( BITS ),
    .ID         ( 1 ),
    .PIPELINE   ( 0 )
) dlsc_compex_c2 (
    .clk        ( clk ),
    .in_id0     ( 1'b0 ),
    .in_id1     ( 1'b0 ),
    .in_data0   ( c2_data0 ),
    .in_data1   ( c2_data1 ),
    .out_id0    (  ),
    .out_id1    (  ),
    .out_data0  ( c3_data0 ),
    .out_data1  ( c3_data1 )
);

assign c3_data2 = c3_data2_r;

endmodule

