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
// Implements a cascade of adders.

module dlsc_adder_cascade #(
    parameter SLICES        = 1,        // number of slices to cascade
    parameter REVERSE       = 0,        // reverse order of cascade (start at N-1 instead of 0)
    parameter BITS          = 8,        // bits for input
    parameter SIB           = 1,        // bits for sum in
    parameter SOB           = BITS      // bits for sum out (>= SIB)
) (
    // system
    input   wire                        clk,

    // inputs
    input   wire    [SLICES*BITS-1:0]   c0_data,

    // sum cascade in
    input   wire    [SIB-1:0]           c0_sum_in,

    // sum cascade out
    // has pipeline delay of SLICES cycles
    // co = c0 + SLICES
    output  wire    [SOB-1:0]           co_sum_out
);

`include "dlsc_util.vh"
`include "dlsc_synthesis.vh"

genvar j;

localparam ADDV     = (2**BITS)-1;
localparam STARTV   = (2**SIB) + ADDV;

wire [SOB-1:0] cascade [SLICES:0];
assign cascade[0] = { {(SOB-SIB){1'b0}} , c0_sum_in };
assign co_sum_out = cascade[SLICES];

wire [SLICES*BITS-1:0] c0_rev;

generate

if(REVERSE) begin:GEN_REV
    for(j=0;j<SLICES;j=j+1) begin:GEN_REV_LOOP
        assign c0_rev[ j*BITS +: BITS ] = c0_data[ (SLICES-1-j)*BITS +: BITS ];
    end
end else begin:GEN_FWD
    assign c0_rev = c0_data;
end

/* verilator lint_off WIDTH */
for(j=0;j<SLICES;j=j+1) begin:GEN_SLICES

    // use just enough bits to hold the max possible output value at this stage
    `DLSC_PIPE_REG reg [`dlsc_clog2_upper( STARTV+j*ADDV , SOB )-1:0] sum;

    always @(posedge clk) begin
        sum <= cascade[j] + c0_rev[ j*BITS +: BITS ];
    end
    
    assign cascade[j+1] = sum;

end
/* verilator lint_on WIDTH */

endgenerate

endmodule

