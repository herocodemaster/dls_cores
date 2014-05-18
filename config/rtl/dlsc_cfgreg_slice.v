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
// Module for implementing semi-static configuration registers.
// Internal flops are named 'dlsc_cfgreg_out_reg' to make it easy for timing
// constraints to specify multicycle paths on the output of config registers.

module dlsc_cfgreg_slice #(
    parameter DATA      = 1,            // width of register
    parameter RESET     = {DATA{1'bx}}, // reset value for register
    parameter IN_DATA   = DATA,         // width of input port
    parameter WARNINGS  = 1             // enable warnings about lost MSbits
) (
    // system
    input   wire                    clk,
    input   wire                    clk_en,
    input   wire                    rst,

    // input
    input   wire    [IN_DATA-1:0]   in,

    // output
    // may have multicycle timing constraint applied
    output  wire    [DATA-1:0]      out
);

`include "dlsc_synthesis.vh"

`DLSC_CONFIG_REG reg [DATA-1:0] dlsc_cfgreg_out_reg;

always @(posedge clk) begin
    if(rst) begin
        dlsc_cfgreg_out_reg <= RESET;
    end else if(clk_en) begin
        dlsc_cfgreg_out_reg <= in[DATA-1:0];
    end
end

assign out = dlsc_cfgreg_out_reg;

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

generate
if(IN_DATA>DATA) begin:CHECK_IN_DATA

always @(posedge clk) begin
    if(!rst && clk_en) begin
        if(|in[IN_DATA-1:DATA]) begin
            `dlsc_warn("MSbits discarded (0x%0x truncated to 0x%0x)", in, in[DATA-1:0]);
        end
    end
end

end
endgenerate

`include "dlsc_sim_bot.vh"
`endif

endmodule

