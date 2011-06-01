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
// Implements a uniqueness-ratio filtering operation (mostly) compatible with
// the one in OpenCV's findStereoCorrespondenceBM function.
//
// In OpenCV, uniquenessRatio is specified as an integer percentage. For
// performance reasons, it is instead specified as an integer ratio here. The
// conversion between the two is:
//
// uniquenessRatio == (UNIQUE_MUL*100)/UNIQUE_DIV
//
// UNIQUE_DIV must be a power-of-2, so it's not practical to have an exact 1:1
// correspondence between OpenCV settings and parameters here (only multiples
// of 25 map exactly).
//
// Code from the C reference model:
//
// int thresh = (sads[x] * (UNIQUE_MUL+UNIQUE_DIV))/UNIQUE_DIV;
// if(sads_thresh[x] <= thresh) {
//     fptr[x] = 0xFF;
// }

module dlsc_stereobm_postprocess_uniqueness #(
    parameter DISP_BITS     = 6,
    parameter DISPARITIES   = (2**DISP_BITS),
    parameter UNIQUE_MUL    = 1,
    parameter UNIQUE_DIV    = 4,    // must be power of 2
    parameter SAD_BITS      = 16,
    parameter OUT_CYCLE     = 7     // at least 7
) (
    // system
    input   wire                        clk,

    // inputs from disparity buffer
    input   wire    [ SAD_BITS-1:0]     in_sad,
    
    // additional inputs for uniqueness checking (UNIQUE_MUL > 0)
    input   wire    [ SAD_BITS-1:0]     in_thresh,

    // output
    output  wire                        out_filtered
);

`include "dlsc_synthesis.vh"
`include "dlsc_clog2.vh"

localparam UNIQUE_MULI      = UNIQUE_MUL + UNIQUE_DIV;

localparam UNIQUE_MUL_BITS  = `dlsc_clog2(UNIQUE_MULI);
localparam UNIQUE_DIV_BITS  = `dlsc_clog2(UNIQUE_DIV);
localparam MULT_BITS        = SAD_BITS + UNIQUE_MUL_BITS;
localparam MULT_DIV_BITS    = MULT_BITS - UNIQUE_DIV_BITS;
localparam PAD              = MULT_DIV_BITS - SAD_BITS;

/* verilator lint_off WIDTH */
wire [UNIQUE_MUL_BITS-1:0] c0_unique_mult = UNIQUE_MULI;
/* verilator lint_on WIDTH */

// register multiplier inputs
`DLSC_PIPE_REG reg [       SAD_BITS-1:0] c1_sad;
`DLSC_PIPE_REG reg [UNIQUE_MUL_BITS-1:0] c1_unique_mult;
always @(posedge clk) begin
    c1_sad          <= in_sad;
    c1_unique_mult  <= c0_unique_mult;
end

// multiplier
wire [MULT_BITS-1:0] c5_sad_mult;
dlsc_multu #(
    .DATA0      ( SAD_BITS ),
    .DATA1      ( UNIQUE_MUL_BITS ),
    .OUT        ( MULT_BITS ),
    .PIPELINE   ( 5 - 1 )
) dlsc_multu_inst (
    .clk        ( clk ),
    .in0        ( c1_sad ),
    .in1        ( c1_unique_mult ),
    .out        ( c5_sad_mult )
);

// delay thresh to c5
wire [SAD_BITS-1:0] c5_sad_cmp;
dlsc_pipedelay #(
    .DATA       ( SAD_BITS ),
    .DELAY      ( 5 )
) dlsc_pipedelay_inst_thresh (
    .clk        ( clk ),
    .in_data    ( in_thresh ),
    .out_data   ( c5_sad_cmp )
);

// compare
`DLSC_NO_SHREG reg [MULT_DIV_BITS-1:0] c6_sad_mult;
`DLSC_NO_SHREG reg [     SAD_BITS-1:0] c6_sad_cmp;
`DLSC_NO_SHREG reg                     c7_cmp;
always @(posedge clk) begin
    c6_sad_mult <= c5_sad_mult[ MULT_BITS-1 : UNIQUE_DIV_BITS ];
    c6_sad_cmp  <= c5_sad_cmp;
    c7_cmp      <= ( { {PAD{1'b0}} , c6_sad_cmp } <= c6_sad_mult );
end

// match output delay
dlsc_pipedelay #(
    .DATA   ( 1 ),
    .DELAY  ( OUT_CYCLE - 7 )
) dlsc_pipedelay_inst_out (
    .clk        ( clk ),
    .in_data    ( c7_cmp ),
    .out_data   ( out_filtered )
);

endmodule


