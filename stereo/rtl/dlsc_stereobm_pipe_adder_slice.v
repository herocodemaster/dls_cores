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
// Implements the "add new and subtract old" function required by
// dlsc_stereobm_pipe_adder in order to efficiently create multiple output rows.

module dlsc_stereobm_pipe_adder_slice #(
    parameter DATA          = 16,
    parameter SUM_BITS      = DATA+4,
    parameter DELAY         = 2
) (
    input   wire                            clk,

    input   wire    [DATA-1:0]              in_sub,
    input   wire    [DATA-1:0]              in_add,

    input   wire    [SUM_BITS-1:0]          in_data,    // should be valid DELAY cycles after in_sub/add

    output  wire    [SUM_BITS-1:0]          out_data
);

`include "dlsc_synthesis.vh"

localparam PAD = SUM_BITS-(DATA+1);

`DLSC_NO_SHREG reg [DATA:0] c1_data;
always @(posedge clk)
    c1_data <= {1'b0,in_add} - {1'b0,in_sub};

wire [DATA:0] cn_data;

dlsc_pipedelay #(
    .DATA   ( DATA+1 ),
    .DELAY  ( DELAY-1 )
) dlsc_pipedelay_inst (
    .clk        ( clk ),
    .in_data    ( c1_data ),
    .out_data   ( cn_data )
);

`DLSC_NO_SHREG reg [SUM_BITS-1:0] out_data_r;
assign out_data = out_data_r;

always @(posedge clk)
    out_data_r <= in_data + { {PAD{cn_data[DATA]}} , cn_data };

endmodule

