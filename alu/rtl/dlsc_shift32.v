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
// 32-bit shifter module for CPU ALU.
// TODO: work-in-progress

module dlsc_shift32 (

    input   wire            clk,

    input   wire            left,       // shift left (instead of right)
    input   wire            sign,       // sign-extend (instead of zero-filling)
    input   wire    [4:0]   shift,      // amount to shift by
    input   wire    [31:0]  in,         // unshifted input
    output  wire    [31:0]  out         // shifted output

);

reg  signed [31:0] ins;
reg  signed [31:0] outs;

assign out = outs;

/* verilator lint_off WIDTH */
always @(posedge clk) begin
    ins     <= in;

    casez({sign,left})
    2'b00: // unsigned right shift (zero-fill msbits)
        outs <= ins >> shift;
    2'b10: // signed right shift (sign-extend into msbits)
        outs <= ins >>> shift;
    2'b?1: // left shift (always zero-fill lsbits)
        outs <= ins << shift;
    endcase
end
/* verilator lint_on WIDTH */

endmodule

