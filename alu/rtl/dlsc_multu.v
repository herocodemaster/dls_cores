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

// split pipelining evenly between input and output
// (output gets an extra stage for odd pipeline counts)
localparam PIPELINE_IN  = PIPELINE/2;
localparam PIPELINE_OUT = PIPELINE - PIPELINE_IN;

// width of full (non-truncated) output result
localparam MULT_BITS    = (DATA0+DATA1);


// ** pipeline inputs **

wire [DATA0    -1:0] in0_s;
wire [DATA1    -1:0] in1_s;

dlsc_pipedelay #(
    .DATA   ( DATA0 ),
    .DELAY  ( PIPELINE_IN )
) dlsc_pipedelay_inst_in0 (
    .clk        ( clk ),
    .in_data    ( in0 ),
    .out_data   ( in0_s )
);

dlsc_pipedelay #(
    .DATA   ( DATA1 ),
    .DELAY  ( PIPELINE_IN )
) dlsc_pipedelay_inst_in1 (
    .clk        ( clk ),
    .in_data    ( in1 ),
    .out_data   ( in1_s )
);


// ** multiply **

wire [MULT_BITS-1:0] out_m;

assign out_m = in0_s * in1_s;


// ** pipeline outputs **

wire [MULT_BITS-1:0] out_s;

dlsc_pipedelay #(
    .DATA   ( MULT_BITS ),
    .DELAY  ( PIPELINE_OUT )
) dlsc_pipedelay_inst_out (
    .clk        ( clk ),
    .in_data    ( out_m ),
    .out_data   ( out_s )
);


// ** assign output **

generate
    if(OUT < MULT_BITS) begin:GEN_OUT_TRUNC
        assign out = out_s[OUT-1:0];
    end else if(OUT == MULT_BITS) begin:GEN_OUT_EXACT
        assign out = out_s;
    end else begin:GEN_OUT_PAD
        assign out = { {(OUT-MULT_BITS){1'b0}} , out_s };
    end
endgenerate


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"
generate
    if(OUT<MULT_BITS) begin:GEN_CHECK_OVERFLOW
        always @(posedge clk) begin
            if(out_s[MULT_BITS-1:OUT] != 0) begin
                `dlsc_warn("multiplier output overflowed! (out = 0x%0x ; out_full = 0x%0x)", out, out_s);
            end
        end
    end
endgenerate
`include "dlsc_sim_bot.vh"
`endif

endmodule

