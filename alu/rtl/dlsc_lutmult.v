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
// Unsigned integer multiplier implemented using a LUT ROM.
// When SCALE is set, result is scaled to use full output range.

module dlsc_lutmult #(
    parameter AB            = 4,                // bits for A input
    parameter BB            = 4,                // bits for B input
    parameter OB            = 4,                // bits for output
    parameter SCALE         = (OB < (AB+BB)),   // scale output to use full range
    parameter FORCE_NONZERO = SCALE             // force output to be non-zero if both inputs are non-zero (only applies when SCALE is set)
) (
    // system
    input   wire                    clk,

    // input
    input   wire    [AB-1:0]        c0_a,
    input   wire    [BB-1:0]        c0_b,

    // output
    output  wire    [OB-1:0]        c1_out
);

`include "dlsc_util.vh"
`include "dlsc_synthesis.vh"

localparam AMAX     = (2**AB)-1;
localparam BMAX     = (2**BB)-1;
localparam ABMAX    = AMAX*BMAX;
localparam OMAX     = (2**OB)-1;

localparam LUTD     = 2**(AB+BB);

integer a, b, i, v;

// create LUT
// done at synthesis time

`DLSC_LUTROM reg [OB-1:0] lut [LUTD-1:0];

/* verilator lint_off WIDTH */
initial begin
    for(a = 0; a <= AMAX; a=a+1) begin
        for(b = 0; b <= BMAX; b=b+1) begin
            v = a * b;
            if(SCALE) begin
                v = ( (OMAX * v) + (ABMAX/2) ) / ABMAX;
                if(FORCE_NONZERO && (a > 0) && (b > 0)) begin
                    v = `dlsc_max(v, 1);
                end
            end
            i = (a << BB) + b;
            lut[i] = `dlsc_min(v, OMAX);
        end
    end
end
/* verilator lint_on WIDTH */

// use LUT

`DLSC_PIPE_REG reg [OB-1:0] c1_out_r;
assign c1_out = c1_out_r;

always @(posedge clk) begin
    c1_out_r <= lut[ { c0_a, c0_b } ];
end

endmodule

