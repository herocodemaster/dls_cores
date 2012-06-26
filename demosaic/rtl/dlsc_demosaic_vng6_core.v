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
// Implements the Variable Number of Gradients (VNG) demosaic algorithm
// described here:
// http://scien.stanford.edu/pages/labsite/1999/psych221/projects/99/tingchen/algodep/vargra.html
//
// The core requires 6 cycles to process each pixel (hence VNG6). Each row
// requires (width+5)*6 total cycles to process.
//
// The core must buffer at least 2 rows before beginning output. It is heavily
// pipelined. First pixel output will occur approximately 70 cycles after the
// 3rd pixel of the 3rd row is supplied.
//
// Input buffering of the next frame is overlapped with output of the current
// frame. The pipeline is flushed between frames, yielding an approximate 100
// cycle delay between the output of the last pixel of the current frame and
// the 1st pixel of the next frame (assuming the input is not throttled).

module dlsc_demosaic_vng6_core #(
    parameter BITS          = 8,            // bits per pixel
    parameter WIDTH         = 1024,         // maximum raw image width
    parameter XB            = 12,           // bits for image width
    parameter YB            = 12            // bits for image height
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // configuration
    // (should be constant out of reset)
    input   wire    [XB-1:0]        cfg_width,      // width of raw image (0 based)
    input   wire    [YB-1:0]        cfg_height,     // height of raw image (0 based)
    input   wire                    cfg_first_r,    // first row has red pixels (otherwise blue)
    input   wire                    cfg_first_g,    // first pixel is green
    
    // pixels in (raw)
    output  wire                    in_ready,
    input   wire                    in_valid,
    input   wire    [BITS-1:0]      in_data,

    // pixels out (color)
    input   wire                    out_ready,
    output  wire                    out_valid,
    output  wire                    out_last,       // last pixel for frame
    output  wire    [BITS-1:0]      out_data_r,
    output  wire    [BITS-1:0]      out_data_g,
    output  wire    [BITS-1:0]      out_data_b
);

// ** input buffer **

wire            buf_ready;
wire            buf_valid;
wire            buf_row_last;
wire            buf_frame_last;
wire [BITS-1:0] buf_data;

dlsc_demosaic_vng6_buffer #(
    .BITS           ( BITS ),
    .XB             ( XB ),
    .YB             ( YB )
) dlsc_demosaic_vng6_buffer (
    .clk            ( clk ),
    .rst            ( rst ),
    .cfg_width      ( cfg_width ),
    .cfg_height     ( cfg_height ),
    .in_ready       ( in_ready ),
    .in_valid       ( in_valid ),
    .in_data        ( in_data ),
    .out_ready      ( buf_ready ),
    .out_valid      ( buf_valid ),
    .out_row_last   ( buf_row_last ),
    .out_frame_last ( buf_frame_last ),
    .out_data       ( buf_data )
);

// ** VNG control **

wire            vng_clk_en;
wire [3:0]      vng_st;
wire            vng_px_push;
wire            vng_px_masked;
wire            vng_px_last;
wire            vng_px_row_red;
wire [BITS-1:0] vng_px_in;

wire            out_almost_full;
wire            vng_out_last;

dlsc_demosaic_vng6_control #(
    .BITS           ( BITS ),
    .XB             ( XB )
) dlsc_demosaic_vng6_control (
    .clk            ( clk ),
    .rst            ( rst ),
    .cfg_width      ( cfg_width ),
    .cfg_first_r    ( cfg_first_r ),
    .cfg_first_g    ( cfg_first_g ),
    .in_ready       ( buf_ready ),
    .in_valid       ( buf_valid ),
    .in_row_last    ( buf_row_last ),
    .in_frame_last  ( buf_frame_last ),
    .in_data        ( buf_data ),
    .vng_clk_en     ( vng_clk_en ),
    .vng_st         ( vng_st ),
    .vng_px_push    ( vng_px_push ),
    .vng_px_masked  ( vng_px_masked ),
    .vng_px_last    ( vng_px_last ),
    .vng_px_row_red ( vng_px_row_red ),
    .vng_px_in      ( vng_px_in ),
    .out_almost_full ( out_almost_full ),
    .out_last       ( vng_out_last )
);

// ** VNG pipeline **
    
wire            vng_out_valid;
wire [BITS-1:0] vng_out_red;
wire [BITS-1:0] vng_out_green;
wire [BITS-1:0] vng_out_blue;

dlsc_demosaic_vng6_pipeline #(
    .DATA           ( BITS )
) dlsc_demosaic_vng6_pipeline (
    .clk            ( clk ),
    .clk_en         ( vng_clk_en ),
    .rst            ( rst ),
    .st             ( vng_st ),
    .px_push        ( vng_px_push ),
    .px_masked      ( vng_px_masked ),
    .px_last        ( vng_px_last ),
    .px_row_red     ( vng_px_row_red ),
    .px_in          ( vng_px_in ),
    .out_valid      ( vng_out_valid ),
    .out_last       ( vng_out_last ),
    .out_red        ( vng_out_red ),
    .out_green      ( vng_out_green ),
    .out_blue       ( vng_out_blue )
);

// ** output FIFO **

dlsc_fifo_rvho #(
    .DEPTH          ( 16 ),
    .DATA           ( 1+3*BITS ),
    .ALMOST_FULL    ( 8 )
) dlsc_fifo_rhvo_out (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( vng_out_valid ),
    .wr_data        ( {vng_out_last,vng_out_red,vng_out_green,vng_out_blue} ),
    .wr_full        (  ),
    .wr_almost_full ( out_almost_full ),
    .wr_free        (  ),
    .rd_ready       ( out_ready ),
    .rd_valid       ( out_valid ),
    .rd_data        ( {out_last,out_data_r,out_data_g,out_data_b} ),
    .rd_almost_empty (  )
);

endmodule

