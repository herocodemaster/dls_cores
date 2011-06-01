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
//
// Thin wrapper that bundles dlsc_stereobm_xsobel with dlsc_stereobm_buffered.
//
// See dlsc_stereobm_core for discussion about OpenCV compatibility.
//
//
// File List:
//  alu/rtl/dlsc_absdiff.v
//  alu/rtl/dlsc_adder_tree.v
//  alu/rtl/dlsc_compex.v
//  alu/rtl/dlsc_divu.v
//  alu/rtl/dlsc_min_tree.v
//  alu/rtl/dlsc_multu.v
//  common/rtl/dlsc_clog2.vh
//  common/rtl/dlsc_synthesis.vh
//  mem/rtl/dlsc_fifo_shiftreg.v
//  mem/rtl/dlsc_pipedelay.v
//  mem/rtl/dlsc_pipedelay_clken.v
//  mem/rtl/dlsc_pipedelay_rst.v
//  mem/rtl/dlsc_pipedelay_valid.v
//  mem/rtl/dlsc_pipereg.v
//  mem/rtl/dlsc_ram_dp.v
//  mem/rtl/dlsc_ram_dp_slice.v
//  mem/rtl/dlsc_shiftreg.v
//  rvh/rtl/dlsc_rowbuffer.v
//  rvh/rtl/dlsc_rowbuffer_combiner.v
//  rvh/rtl/dlsc_rowbuffer_splitter.v
//  rvh/rtl/dlsc_rvh_decoupler.v
//  stereo/rtl/dlsc_stereobm_backend.v
//  stereo/rtl/dlsc_stereobm_buffered.v
//  stereo/rtl/dlsc_stereobm_core.v
//  stereo/rtl/dlsc_stereobm_disparity.v
//  stereo/rtl/dlsc_stereobm_disparity_slice.v
//  stereo/rtl/dlsc_stereobm_frontend.v
//  stereo/rtl/dlsc_stereobm_frontend_control.v
//  stereo/rtl/dlsc_stereobm_multipipe.v
//  stereo/rtl/dlsc_stereobm_pipe.v
//  stereo/rtl/dlsc_stereobm_pipe_accumulator.v
//  stereo/rtl/dlsc_stereobm_pipe_accumulator_slice.v
//  stereo/rtl/dlsc_stereobm_pipe_adder.v
//  stereo/rtl/dlsc_stereobm_pipe_adder_slice.v
//  stereo/rtl/dlsc_stereobm_postprocess.v
//  stereo/rtl/dlsc_stereobm_postprocess_subpixel.v
//  stereo/rtl/dlsc_stereobm_postprocess_uniqueness.v
//  stereo/rtl/dlsc_stereobm_prefiltered.v
//  stereo/rtl/dlsc_xsobel_core.v
//  sync/rtl/dlsc_domaincross.v
//  sync/rtl/dlsc_domaincross_slice.v
//  sync/rtl/dlsc_syncflop.v
//  sync/rtl/dlsc_syncflop_slice.v

module dlsc_stereobm_prefiltered #(

    // pixel size
    parameter DATA              = 8,                // bits per input pixel
    parameter DATAF             = 4,                // bits per filtered/output pixel
    parameter DATAF_MAX         = ((2**DATAF)-1),   // maximum possible filtered pixel value (set to twice OpenCV's preFilterCap)

    // image size
    parameter IMG_WIDTH         = 752,              // width of input image
    parameter IMG_HEIGHT        = 480,              // height of input image

    // disparity search space
    parameter DISP_BITS         = 7,                // width of output disparity data; must be enough for DISPARITIES-1
    parameter DISPARITIES       = (2**DISP_BITS),   // number of disparity levels to search
    parameter SAD_WINDOW        = 17,               // size of SAD comparison window (must be odd)

    // post-processing
    parameter TEXTURE           = 1200,             // texture filtering (0 to disable)
    parameter SUB_BITS          = 4,                // bits for sub-pixel interpolation (0 to disable; increases width of output disparities beyond DISP_BITS)
    parameter SUB_BITS_EXTRA    = 4,                // extra internal sub-pixel bits for rounding (must be 4 for OpenCV compatibility)
    parameter UNIQUE_MUL        = 1,                // uniqueness filtering - threshold multiplier (0 to disable)
    parameter UNIQUE_DIV        = 4,                // uniqueness filtering - threshold divider (must be non-zero; must be power of 2)

    // output options
    parameter OUT_LEFT          = 1,                // enable out_left
    parameter OUT_RIGHT         = 1,                // enable out_right

    // parallelization
    parameter MULT_D            = 8,                // number of disparities to compute in parallel (DISPARITIES must be integer multiple of this)
    parameter MULT_R            = 2,                // number of rows to run in parallel (IMG_HEIGHT and SAD_WINDOW/2 must be integer multiple of this)
    
    // synthesis performance tuning parameters
    parameter PIPELINE_BRAM_RD  = 1,                // needed by most architectures
    parameter PIPELINE_BRAM_WR  = 0,                // needed by Virtex-6 (and sometimes Spartan-6)
    parameter PIPELINE_FANOUT   = 0,                // needed by Virtex-6
    parameter PIPELINE_LUT4     = 1,                // needed by Spartan-3

    // derived parameters; don't touch
    parameter DISP_BITS_S       = (DISP_BITS+SUB_BITS)      // width of output disparity data port
) (
    // system
    input   wire                        core_clk,           // high-speed clock for stereo core (can be asynchronous to clk)
    input   wire                        clk,                // clock; all inputs synchronous to this; all outputs registered by this
    input   wire                        rst,                // synchronous reset

    // input
    output  wire                        in_ready,           // ready/valid handshake for all input signals
    input   wire                        in_valid,           // ""
    input   wire    [DATA  -1:0]        in_left,            // rectified left image data
    input   wire    [DATA  -1:0]        in_right,           // rectified right image data
    
    // output
    input   wire                        out_ready,          // ready/valid handshake for all output signals
    output  wire                        out_valid,          // ""
    output  wire    [DISP_BITS_S-1:0]   out_disp,           // disparity values for out_left image data
    output  wire                        out_masked,         // disparity value was outside valid region
    output  wire                        out_filtered,       // disparity value was filtered out by post-processing
    output  wire    [DATAF -1:0]        out_left,           // left image data (delayed and filtered in_left)
    output  wire    [DATAF -1:0]        out_right           // right image data (delayed and filtered in_right)
);

wire             xsobel_ready;
wire             xsobel_valid;
wire [DATAF-1:0] xsobel_left;
wire [DATAF-1:0] xsobel_right;

// filter left image
dlsc_xsobel_core #(
    .IN_DATA            ( DATA ),
    .OUT_DATA           ( DATAF ),
    .OUT_CLAMP          ( DATAF_MAX ),
    .IMG_WIDTH          ( IMG_WIDTH ),
    .IMG_HEIGHT         ( IMG_HEIGHT )
) dlsc_xsobel_core_inst_left (
    .clk                ( clk ),
    .rst                ( rst ),
    .in_ready           ( in_ready ),
    .in_valid           ( in_valid ),
    .in_px              ( in_left ),
    .out_ready          ( xsobel_ready ),
    .out_valid          ( xsobel_valid ),
    .out_px             ( xsobel_left )
);

// filter right image
dlsc_xsobel_core #(
    .IN_DATA            ( DATA ),
    .OUT_DATA           ( DATAF ),
    .OUT_CLAMP          ( DATAF_MAX ),
    .IMG_WIDTH          ( IMG_WIDTH ),
    .IMG_HEIGHT         ( IMG_HEIGHT )
) dlsc_xsobel_core_inst_right (
    .clk                ( clk ),
    .rst                ( rst ),
    .in_ready           (  ), // should be the same as in_ready of _inst_left
    .in_valid           ( in_valid ),
    .in_px              ( in_right ),
    .out_ready          ( xsobel_ready ),
    .out_valid          (  ), // should be the same as out_valid of _inst_left
    .out_px             ( xsobel_right )
);

// compute stereo correspondence
dlsc_stereobm_buffered #(
    .DATA               ( DATAF ),
    .DATA_MAX           ( DATAF_MAX ),
    .IMG_WIDTH          ( IMG_WIDTH ),
    .IMG_HEIGHT         ( IMG_HEIGHT ),
    .DISP_BITS          ( DISP_BITS ),
    .DISPARITIES        ( DISPARITIES ),
    .SAD_WINDOW         ( SAD_WINDOW ),
    .TEXTURE            ( TEXTURE ),
    .SUB_BITS           ( SUB_BITS ),
    .SUB_BITS_EXTRA     ( SUB_BITS_EXTRA ),
    .UNIQUE_MUL         ( UNIQUE_MUL ),
    .UNIQUE_DIV         ( UNIQUE_DIV ),
    .OUT_LEFT           ( OUT_LEFT ),
    .OUT_RIGHT          ( OUT_RIGHT ),
    .MULT_D             ( MULT_D ),
    .MULT_R             ( MULT_R ),
    .PIPELINE_BRAM_RD   ( PIPELINE_BRAM_RD ),
    .PIPELINE_BRAM_WR   ( PIPELINE_BRAM_WR ),
    .PIPELINE_FANOUT    ( PIPELINE_FANOUT ),
    .PIPELINE_LUT4      ( PIPELINE_LUT4 )
) dlsc_stereobm_buffered_inst (
    .core_clk           ( core_clk ),
    .clk                ( clk ),
    .rst                ( rst ),
    .in_ready           ( xsobel_ready ),
    .in_valid           ( xsobel_valid ),
    .in_left            ( xsobel_left ),
    .in_right           ( xsobel_right ),
    .out_ready          ( out_ready ),
    .out_valid          ( out_valid ),
    .out_disp           ( out_disp ),
    .out_masked         ( out_masked ),
    .out_filtered       ( out_filtered ),
    .out_left           ( out_left ),
    .out_right          ( out_right )
);

endmodule

