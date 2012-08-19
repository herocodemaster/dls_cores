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
// Unsigned integer multiplier; should infer FPGA multiplier primitive.
// Optional pipelining improves performance. PIPELINE parameter sets number
// of cycles through multiplier (recommend 3-4 for Xilinx DSP48 blocks).

module dlsc_multu #(
    parameter DATA0     = 17,               // width of first operand
    parameter DATA1     = 17,               // width of second operand
    parameter OUT       = (DATA0+DATA1),    // width of output
    parameter PIPELINE  = 4                 // pipeline delay (recommend 3-4 for Xilinx DSP48 blocks)
) (
    input   wire                clk,

    input   wire    [DATA0-1:0] in0,
    input   wire    [DATA1-1:0] in1,
    output  wire    [OUT  -1:0] out
);

dlsc_mult #(
    .SIGNED     ( 0 ),
    .DATA0      ( DATA0 ),
    .DATA1      ( DATA1 ),
    .OUT        ( OUT ),
    .PIPELINE   ( PIPELINE )
) dlsc_mult (
    .clk        ( clk ),
    .clk_en     ( 1'b1 ),
    .in0        ( in0 ),
    .in1        ( in1 ),
    .out        ( out )
);

endmodule

