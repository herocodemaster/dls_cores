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
//
// Converts color (RGB) images to grayscale using programmable weighting.
//
// Operation yields:
// out = saturate( ( (r * mult_r) + (g * mult_g) + (b * mult_b) + (1<<CBITS)/2 ) >> CBITS )
//

module dlsc_grayscale_core #(
    parameter BITS          = 8,            // bits per pixel
    parameter CBITS         = 4             // bits for coefficients
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // configuration
    input   wire    [CBITS-1:0]     cfg_mult_r,
    input   wire    [CBITS-1:0]     cfg_mult_g,
    input   wire    [CBITS-1:0]     cfg_mult_b,

    // pixels in (color)
    output  wire                    in_ready,
    input   wire                    in_valid,
    input   wire    [BITS-1:0]      in_data_r,
    input   wire    [BITS-1:0]      in_data_g,
    input   wire    [BITS-1:0]      in_data_b,

    // pixels out (grayscale)
    input   wire                    out_ready,
    output  wire                    out_valid,
    output  wire    [BITS-1:0]      out_data
);

localparam MBITS = BITS+CBITS;  // bits for output of multiply operation


// ** multiply **

wire [MBITS-1:0]    c4_r;
wire [MBITS-1:0]    c4_g;
wire [MBITS-1:0]    c4_b;

// red
dlsc_multu #(
    .DATA0      ( BITS ),
    .DATA1      ( CBITS ),
    .OUT        ( MBITS ),
    .PIPELINE   ( 4 )
) dlsc_multu_r (
    .clk        ( clk ),
    .in0        ( in_data_r ),
    .in1        ( cfg_mult_r ),
    .out        ( c4_r )
);

// green
dlsc_multu #(
    .DATA0      ( BITS ),
    .DATA1      ( CBITS ),
    .OUT        ( MBITS ),
    .PIPELINE   ( 4 )
) dlsc_multu_g (
    .clk        ( clk ),
    .in0        ( in_data_g ),
    .in1        ( cfg_mult_g ),
    .out        ( c4_g )
);

// blue
dlsc_multu #(
    .DATA0      ( BITS ),
    .DATA1      ( CBITS ),
    .OUT        ( MBITS ),
    .PIPELINE   ( 4 )
) dlsc_multu_b (
    .clk        ( clk ),
    .in0        ( in_data_b ),
    .in1        ( cfg_mult_b ),
    .out        ( c4_b )
);


// ** sum and divide **

reg  [MBITS:0]  c5_rg;
reg  [MBITS:0]  c5_bb;

reg  [MBITS+1:0] c6_sum;
wire [BITS+1:0] c6_div  = c6_sum[MBITS+1:CBITS];

always @(posedge clk) begin
    c5_rg       <= {1'b0,c4_r} + {1'b0,c4_g};
    c5_bb       <= {1'b0,c4_b} + (2**(CBITS-1));    // round by biasing to half of divide value
    c6_sum      <= {1'b0,c5_rg} + {1'b0,c5_bb};
end


// ** clamp **

wire            c6_div_overflow = |c6_div[BITS+1:BITS];
reg  [BITS-1:0] c7_clamp;

always @(posedge clk) begin
    c7_clamp    <= c6_div_overflow ? {BITS{1'b1}} : c6_div[BITS-1:0];
end


// ** valids **

wire            c7_valid;

dlsc_pipedelay_rst #(
    .DATA       ( 1 ),
    .DELAY      ( 7 ),
    .RESET      ( 1'b0 )
) dlsc_pipedelay_rst_c7 (
    .clk        ( clk ),
    .rst        ( rst ),
    .in_data    ( in_ready && in_valid ),
    .out_data   ( c7_valid )
);


// ** FIFO **

wire wr_almost_full;
assign in_ready = !wr_almost_full;

dlsc_fifo_rvho #(
    .DEPTH          ( 16 ),
    .DATA           ( BITS ),
    .ALMOST_FULL    ( 8 ),
    .FULL_IN_RESET  ( 1 )
) dlsc_fifo_rvho (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( c7_valid ),
    .wr_data        ( c7_clamp ),
    .wr_full        (  ),
    .wr_almost_full ( wr_almost_full ),
    .wr_free        (  ),
    .rd_ready       ( out_ready ),
    .rd_valid       ( out_valid ),
    .rd_data        ( out_data ),
    .rd_almost_empty (  )
);


endmodule

