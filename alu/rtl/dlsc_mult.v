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
// Integer multiplier with support for unsigned and signed values and fixed-
// point values.

module dlsc_mult #(
    parameter DEVICE    = "GENERIC",
    parameter SIGNED    = 0,            // set for signed multiplication
    parameter DATA0     = 1,            // total bits for first operand (including sign bit and fractional bits)
    parameter DATA1     = 1,            // total bits for second operand ("")
    parameter OUT       = 1,            // total bits for output ("")
    parameter DATAF0    = 0,            // fractional bits for first operand
    parameter DATAF1    = 0,            // fractional bits for second operand
    parameter OUTF      = 0,            // fractional bits for output
    parameter CLAMP     = 0,            // clamp output on overflow (if set, PIPELINE must be >= 1)
    parameter PIPELINE  = 4,            // pipeline delay (recommend 3-5 for Xilinx DSP48 blocks; 4-6 if using CLAMP)
    parameter WARNINGS  = 1             // enable warnings for unclamped overflows
) (
    input   wire                clk,
    input   wire                clk_en,

    input   wire    [DATA0-1:0] in0,
    input   wire    [DATA1-1:0] in1,
    output  wire    [OUT  -1:0] out
);

`include "dlsc_util.vh"
`include "dlsc_synthesis.vh"

localparam SHIFT        = (DATAF0+DATAF1-OUTF);
localparam RSHIFT       = (SHIFT>0) ? (  SHIFT) : 0;
localparam LSHIFT       = (SHIFT<0) ? (0-SHIFT) : 0;
localparam OUTIP        = DATA0 + DATA1;
localparam OUTILS       = OUTIP + LSHIFT;
localparam OUTI         = OUTILS - RSHIFT;
localparam CLAMPI       = CLAMP && (OUTI > OUT);
localparam PIPELINEM    = CLAMPI ? (PIPELINE-1) : (PIPELINE);

`dlsc_static_assert_lt( `dlsc_abs(SHIFT), OUTIP )
`dlsc_static_assert_gte( PIPELINEM, 0 )

// multiply and left-shift

wire signed [OUTILS:0] mout;

dlsc_mult_core #(
    .DEVICE     ( DEVICE ),
    .SIGNED     ( SIGNED ),
    .DATA0      ( DATA0 ),
    .DATA1      ( DATA1 ),
    .OUT        ( OUTIP ),
    .PIPELINE   ( PIPELINEM )
) dlsc_mult_core (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .in0        ( in0 ),
    .in1        ( in1 ),
    .out        ( mout[ OUTILS-1 -: OUTIP ] )
);

generate
if(SIGNED) begin:GEN_MOUT_MSB_SIGNED
    assign mout[OUTILS] = mout[OUTILS-1];
end else begin:GEN_MOUT_MSB_UNSIGNED
    assign mout[OUTILS] = 1'b0;
end
if(LSHIFT>0) begin:GEN_MOUT_LSB_ZERO
    assign mout[0 +: LSHIFT] = 'd0;
end
endgenerate

// right-shift

wire signed [OUTILS:0] mouts = mout >>> RSHIFT;

// clamp

wire overflow;

generate
if(OUTI > OUT) begin:GEN_OVERFLOW
    if(SIGNED) begin:GEN_OVERFLOW_SIGNED

        assign overflow = (mouts[OUTI-1:OUT] != {(OUTI-OUT){mouts[OUT-1]}});

    end else begin:GEN_OVERFLOW_UNSIGNED

        assign overflow = (mouts[OUTI-1:OUT] != {(OUTI-OUT){1'b0}});

    end
end else begin:GEN_NO_OVERFLOW

    assign overflow = 1'b0;

end
if(CLAMPI) begin:GEN_CLAMP

    `DLSC_PIPE_REG reg [OUT-1:0] outr;
    assign out = outr;

    if(SIGNED) begin:GEN_CLAMP_SIGNED

        always @(posedge clk) begin
            if(clk_en) begin
                outr <= (!overflow) ? mouts[OUT-1:0] :
                    ( mouts[OUTI-1] ? { 1'b1, {(OUT-1){1'b0}} } : { 1'b0, {(OUT-1){1'b1}} } );
            end
        end

    end else begin: GEN_CLAMP_UNSIGNED

        always @(posedge clk) begin
            if(clk_en) begin
                outr <= overflow ? {OUT{1'b1}} : mouts[OUT-1:0];
            end
        end

    end
end else if(OUT <= OUTILS) begin:GEN_NCLAMP

    assign out = mouts[OUT-1:0];

end else begin:GEN_PAD
    if(SIGNED) begin:GEN_PAD_SIGNED

        assign out = { {(OUT-OUTILS){mouts[OUTILS]}} , mouts[OUTILS-1:0] };

    end else begin:GEN_PAD_UNSIGNED
        
        assign out = { {(OUT-OUTILS){1'b0}} , mouts[OUTILS-1:0] };

    end
end
endgenerate

endmodule

