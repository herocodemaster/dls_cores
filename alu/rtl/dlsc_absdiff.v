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

module dlsc_absdiff #(
    parameter WIDTH     = 32,
    parameter META      = 1
) (
    input   wire                    clk,
    input   wire                    rst,

    input   wire                    in_valid,
    input   wire    [META-1:0]      in_meta,
    input   wire    [WIDTH-1:0]     in0,
    input   wire    [WIDTH-1:0]     in1,

    output  reg                     out_valid,
    output  reg     [META-1:0]      out_meta,
    output  wire    [WIDTH-1:0]     out
);

`include "dlsc_synthesis.vh"

reg                 diff_valid;
reg  [META-1:0]     diff_meta;
reg  [WIDTH:0]      diff;

// take absolute value
wire                diff_neg = diff[WIDTH];

always @(posedge clk) begin
    if(rst) begin
        { out_valid, diff_valid } <= 2'b00;
    end else begin
        { out_valid, diff_valid } <= { diff_valid, in_valid };
    end
end

`DLSC_NO_SHREG reg [WIDTH-1:0] out_r;
assign out = out_r;

always @(posedge clk) begin
    // compute difference
    diff_meta   <= in_meta;
    diff        <= {1'b0,in0} - {1'b0,in1};
    // take absolute value
    out_meta    <= diff_meta;
    out_r       <= ( diff[WIDTH-1:0] ^ {WIDTH{diff_neg}} ) + {{(WIDTH-1){1'b0}},diff_neg};
end

endmodule

