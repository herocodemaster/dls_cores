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
// Implements a compare-and-exchange function.
// The output always has out_data0 <= out_data1.
// Pipeline delay is 1 or 2 cycles (2 if PIPELINE is set)

module dlsc_demosaic_vng6_compex #(
    parameter DATA      = 16,
    parameter PIPELINE  = 0
) (
    input   wire                clk,
    input   wire                clk_en,
    input   wire    [DATA-1:0]  in_data0,
    input   wire    [DATA-1:0]  in_data1,
    output  wire    [DATA-1:0]  out_data0,
    output  wire    [DATA-1:0]  out_data1
);

`include "dlsc_synthesis.vh"

// ** find lower value **
wire c0_zero_wins = (in_data0 <= in_data1);
reg [DATA-1:0] c1_data0;
reg [DATA-1:0] c1_data1;
reg            c1_zero_wins;
always @(posedge clk) if(clk_en) begin
    c1_data0        <= in_data0;
    c1_data1        <= in_data1;
    c1_zero_wins    <= c0_zero_wins;
end

// ** mux outputs **
wire [DATA-1:0] pre_data0  = ( c1_data0 & {DATA{ c1_zero_wins}} ) | ( c1_data1 & {DATA{!c1_zero_wins}} );
wire [DATA-1:0] pre_data1  = ( c1_data0 & {DATA{!c1_zero_wins}} ) | ( c1_data1 & {DATA{ c1_zero_wins}} );

// ** optional pipelining **
generate
    if(PIPELINE) begin:GEN_PIPE
        `DLSC_NO_SHREG reg [DATA-1:0] c2_data0;
        `DLSC_NO_SHREG reg [DATA-1:0] c2_data1;
        always @(posedge clk) if(clk_en) begin
            c2_data0   <= pre_data0;
            c2_data1   <= pre_data1;
        end
        assign out_data0    = c2_data0;
        assign out_data1    = c2_data1;
    end else begin:GEN_NOPIPE
        assign out_data0    = pre_data0;
        assign out_data1    = pre_data1;
    end
endgenerate

endmodule

