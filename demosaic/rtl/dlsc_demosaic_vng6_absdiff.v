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
// Computes the absolute difference of two input values.
// Pipeline latency is 2 cycles.

module dlsc_demosaic_vng6_absdiff #(
    parameter DATA = 8
) (
    input   wire                clk,
    input   wire                clk_en,

    input   wire    [DATA-1:0]  in0,
    input   wire    [DATA-1:0]  in1,

    output  wire    [DATA-1:0]  out
);

`include "dlsc_synthesis.vh"

reg  [DATA:0]       diff;

// take absolute value
wire                diff_neg = diff[DATA];

`DLSC_NO_SHREG reg [DATA-1:0] out_r;
assign out = out_r;

always @(posedge clk) if(clk_en) begin
    // compute difference
    diff        <= {1'b0,in0} - {1'b0,in1};
    // take absolute value
    out_r       <= ( diff[DATA-1:0] ^ {DATA{diff_neg}} ) + {{(DATA-1){1'b0}},diff_neg};
end

endmodule

