// 
// Copyright (c) 2012, Daniel Strother < http://danstrother.com/ >
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
// Integer multiplier (unsigned or signed). Should infer FPGA multiplier
// primitive. Optional pipelining improves performance. PIPELINE parameter
// sets number of cycles through multiplier (a value of 3-4 is recommended
// for Xilinx DSP48 blocks).

module dlsc_mult_generic #(
    parameter SIGNED    = 0,            // set for signed multiplication
    parameter DATA0     = 1,            // width of first operand (should typically be >= DATA1)
    parameter DATA1     = 1,            // width of second operand
    parameter OUT       = 1,            // width of output
    parameter PIPELINE  = 4             // pipeline delay (recommend 3-4 for Xilinx DSP48 blocks)
) (
    input   wire                clk,
    input   wire                clk_en,

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

dlsc_pipedelay_clken #(
    .DATA   ( DATA0 ),
    .DELAY  ( PIPELINE_IN )
) dlsc_pipedelay_inst_in0 (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .in_data    ( in0 ),
    .out_data   ( in0_s )
);

dlsc_pipedelay_clken #(
    .DATA   ( DATA1 ),
    .DELAY  ( PIPELINE_IN )
) dlsc_pipedelay_inst_in1 (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .in_data    ( in1 ),
    .out_data   ( in1_s )
);

// ** multiply **

wire [MULT_BITS-1:0] out_m;

generate
if(SIGNED) begin:GEN_SIGNED

    wire signed [DATA0-1:0]     in0_ss  = in0_s;
    wire signed [DATA1-1:0]     in1_ss  = in1_s;
    wire signed [MULT_BITS-1:0] out_ms;

    // signed multiplication
    assign out_ms = in0_ss * in1_ss;

    assign out_m = out_ms;

end else begin:GEN_UNSIGNED

    // unsigned multiplication
    assign out_m = in0_s * in1_s;

end
endgenerate

// ** pipeline outputs **

wire [MULT_BITS-1:0] out_s;

dlsc_pipedelay_clken #(
    .DATA   ( MULT_BITS ),
    .DELAY  ( PIPELINE_OUT )
) dlsc_pipedelay_inst_out (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
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
        if(SIGNED) begin:PAD_SIGNED
            assign out = { {(OUT-MULT_BITS){out_s[MULT_BITS-1]}} , out_s };
        end else begin:PAD_UNSIGNED
            assign out = { {(OUT-MULT_BITS){1'b0}} , out_s };
        end
    end
endgenerate

endmodule

