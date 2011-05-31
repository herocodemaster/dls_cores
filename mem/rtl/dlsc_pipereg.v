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
// Implements an optional pipeline register. When PIPELINE is 0, this does
// nothing. Otherwise, creates a single register level that has constraints
// to prevent shift-register inference and equivalent-register-removal (for
// improved performance).
// If you want more than 1 cycle of delay, you probably want dlsc_pipedelay.

module dlsc_pipereg #(
    parameter DATA      = 32,
    parameter PIPELINE  = 0
) (
    input   wire                clk,

    input   wire    [DATA-1:0]  in_data,

    output  wire    [DATA-1:0]  out_data
);

`include "dlsc_synthesis.vh"

generate
    integer i;
    genvar j;

    if(PIPELINE == 0) begin:GEN_DELAY0

        assign out_data     = in_data;

    end else begin:GEN_DELAY1

        `DLSC_PIPE_REG reg [DATA-1:0] out_data_r0;

        always @(posedge clk)
            out_data_r0 <= in_data;

        assign out_data  = out_data_r0;

    end
endgenerate

endmodule
    
