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
// Implements the same stereo correspondence block-matching alogrithm as
// OpenCV's findStereoCorrespondenceBM (specifically: the non-SSE version
// present in OpenCV 2.2.0).
//
//
// Supported features from OpenCV's CvStereoBMState are:
//
// preFilterType:
//      CV_STEREO_BM_XSOBEL supported through separate external module
//      (dlsc_xsobel_core; dlsc_stereobm_prefiltered includes both this
//      module and the xsobel core). CV_STEREO_BM_NORMALIZED_RESPONSE is not
//      currently supported.
// preFilterSize:
//      Not applicable for CV_STEREO_BM_XSOBEL.
// preFilterCap:
//      Supported by dlsc_xsobel_core/dlsc_stereobm_prefiltered (see DATA_MAX
//      parameter below).
// SADWindowSize:
//      Supported (see SAD_WINDOW parameter below).
// minDisparity:
//      Not currently supported (fixed at 0).
// numberOfDisparities:
//      Supported (see DISPARITIES and DISP_BITS parameters below)
// textureThreshold:
//      Supported (see TEXTURE and DATA_MAX parameters below)
// uniquenessRatio:
//      Supported (see UNIQUE_MUL and UNIQUE_DIV parameters below; conversion
//      is: uniquenessRatio == (UNIQUE_MUL*100/UNIQUE_DIV))
// speckleRange:
// speckleWindowSize:
//      Not currently supported.
//
//
// Module Performance:
//
// The core requires (DISPARITIES/MULT_D) passes to process MULT_R rows
// (one additional pass is required if TEXTURE is enabled).
// Each pass takes approximately (IMG_WIDTH-DISPARITIES+SAD) cycles.
//
// Data is input/output only on the last pass of a row; the core's interfaces
// are idle during the other passes. If the core's interfaces are externally
// throttled, throughput will be reduced. Use of dlsc_stereobm_buffered is
// recommended if your system cannot efficiently handle these bursty transfers.
//
//
// File List:
//  alu/rtl/dlsc_absdiff.v
//  alu/rtl/dlsc_adder_tree.v
//  alu/rtl/dlsc_compex.v
//  alu/rtl/dlsc_divu.v
//  alu/rtl/dlsc_min_tree.v
//  alu/rtl/dlsc_multu.v
//  common/dlsc_clog2.vh
//  mem/rtl/dlsc_pipedelay.v
//  mem/rtl/dlsc_pipedelay_clken.v
//  mem/rtl/dlsc_pipedelay_rst.v
//  mem/rtl/dlsc_pipedelay_valid.v
//  mem/rtl/dlsc_pipereg.v
//  mem/rtl/dlsc_ram_dp.v
//  mem/rtl/dlsc_ram_dp_slice.v
//  stereo/rtl/dlsc_stereobm_backend.v
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

module dlsc_stereobm_core #(

    // pixel size
    parameter DATA              = 8,                // bits per pixel
    parameter DATA_MAX          = ((2**DATA)-1),    // maximum possible pixel value (set to twice OpenCV's preFilterCap)

    // image size
    parameter IMG_WIDTH         = 384,              // width of input image
    parameter IMG_HEIGHT        = 288,              // height of input image

    // disparity search space
    parameter DISP_BITS         = 7,                // width of output disparity data; must be enough for DISPARITIES-1
    parameter DISPARITIES       = (2**DISP_BITS),   // number of disparity levels to search
    parameter SAD_WINDOW        = 17,               // size of SAD comparison window (must be odd)

    // post-processing
    parameter TEXTURE           = 0,                // texture filtering (0 to disable)
    parameter SUB_BITS          = 4,                // bits for sub-pixel interpolation (0 to disable; increases width of output disparities beyond DISP_BITS)
    parameter SUB_BITS_EXTRA    = 4,                // extra internal sub-pixel bits for rounding (must be 4 for strict OpenCV compatibility)
    parameter UNIQUE_MUL        = 1,                // uniqueness filtering - threshold multiplier (0 to disable)
    parameter UNIQUE_DIV        = 4,                // uniqueness filtering - threshold divider (must be non-zero; must be power of 2)
    
    // parallelization
    parameter MULT_D            = 8,                // number of disparities to compute in parallel (DISPARITIES must be integer multiple of this)
    parameter MULT_R            = 2,                // number of rows to run in parallel (IMG_HEIGHT and SAD_WINDOW/2 must be integer multiple of this)
                                                    // (inputs/outputs of block are columns of MULT_R pixels)
    // synthesis performance tuning parameters
    parameter PIPELINE_BRAM_RD  = 1,                // needed by most architectures
    parameter PIPELINE_BRAM_WR  = 0,                // needed by Virtex-6 (and sometimes Spartan-6)
    parameter PIPELINE_FANOUT   = 0,                // needed by Virtex-6
    parameter PIPELINE_LUT4     = 0,                // needed by Spartan-3

    // derived parameters; don't touch
    parameter DATA_R            = (DATA*MULT_R),                // width of whole input image data port
    parameter DISP_BITS_SR      = ((DISP_BITS+SUB_BITS)*MULT_R) // width of whole output disparity data port
) (
    // system
    input   wire                        clk,                // clock; all inputs synchronous to this; all outputs registered by this
    input   wire                        rst,                // synchronous reset

    // input
    output  wire                        in_ready,           // ready/valid handshake for all input signals
    input   wire                        in_valid,           // ""
    input   wire    [DATA_R-1:0]        in_left,            // rectified left image data
    input   wire    [DATA_R-1:0]        in_right,           // rectified right image data
    
    // output
    input   wire                        out_busy,           // busy flag from downstream logic (downstream must be able to consume 50~100 more values *after* asserting busy)
    output  wire                        out_disp_valid,     // qualifier for out_disp_ signals
    output  wire    [DISP_BITS_SR-1:0]  out_disp_data,      // disparity values for out_left image data
    output  wire    [MULT_R-1:0]        out_disp_masked,    // disparity value was outside valid region
    output  wire    [MULT_R-1:0]        out_disp_filtered,  // disparity value was filtered out by post-processing
    output  wire                        out_img_valid,      // qualifier for out_img_ signals
    output  wire    [DATA_R-1:0]        out_img_left,       // left image data (delayed in_left)
    output  wire    [DATA_R-1:0]        out_img_right       // right image data (delayed in_right)
);


localparam SAD = SAD_WINDOW;

`include "dlsc_clog2.vh"
localparam SAD_BITS     = DATA + `dlsc_clog2(SAD*SAD);  // width of data after window SAD
localparam SAD_BITS_R   = (SAD_BITS*MULT_R);
localparam SAD_BITS_RD  = (SAD_BITS*MULT_R*MULT_D);

localparam DISP_BITS_S  = (DISP_BITS+SUB_BITS);
localparam DISP_BITS_R  = (DISP_BITS*MULT_R);

localparam SAD_R        = (SAD+MULT_R-1);


`ifdef SIMULATION
/* verilator coverage_off */
// check configuration parameters
initial begin
    if(DISPARITIES > (2**DISP_BITS)) begin
        $display("[%m] *** ERROR *** DISP_BITS (%0d) insufficient to hold DISPARITIES (%0d)", DISP_BITS, DISPARITIES);
    end
    if(DISPARITIES % MULT_D != 0) begin
        $display("[%m] *** ERROR *** DISPARITIES (%0d) must be integer multiple of MULT_D (%0d)", DISPARITIES, MULT_D);
    end
    if(IMG_HEIGHT % MULT_R != 0) begin
        $display("[%m] *** ERROR *** IMG_HEIGHT (%0d) must be integer multiple of MULT_R (%0d)", IMG_HEIGHT, MULT_R);
    end
    if(SAD_WINDOW % 2 != 1) begin
        $display("[%m] *** ERROR *** SAD_WINDOW (%0d) must be odd", SAD_WINDOW);
    end
    if((SAD_WINDOW/2) % MULT_R != 0) begin
        $display("[%m] *** ERROR *** SAD_WINDOW/2 (%0d) must be integer multiple of MULT_R (%0d)", (SAD_WINDOW/2), MULT_R);
    end
    if((SAD_WINDOW/2) < MULT_R) begin
        $display("[%m] *** ERROR *** SAD_WINDOW/2 (%0d) should not be less than MULT_R (%0d)", (SAD_WINDOW/2), MULT_R);
    end
    if(UNIQUE_MUL > 0) begin
        if(UNIQUE_DIV == 0 || UNIQUE_DIV != (2**(`dlsc_clog2(UNIQUE_DIV))) ) begin
            $display("[%m] *** ERROR *** UNIQUE_DIV (%0d) must be non-zero and a power-of-2", UNIQUE_DIV);
        end
        if(SAD_BITS >= 18) begin
            $display("[%m] *** WARNING *** SAD_BITS (DATA + clog2(SAD_WINDOW**2) = %0d) exceeds 17 bits; with UNIQUENESS filtering enabled, this may lead to poor timing results in FPGA architectures with 18-bit signed multipliers (e.g. most Xilinx devices)", SAD_BITS);
        end
    end
end
/* verilator coverage_on */
`endif


// frontend -> pipeline
wire                        front_right_valid;
wire                        front_valid;
wire                        front_first;
wire    [(DATA*SAD_R)-1:0]  front_left;
wire    [(DATA*SAD_R)-1:0]  front_right;

// frontend -> backend
wire                        back_valid;
wire    [DATA_R-1:0]        back_left;
wire    [DATA_R-1:0]        back_right;

// pipeline -> disparity buffer
wire                        pipe_valid;
wire    [ SAD_BITS_RD-1:0]  pipe_sad;

// disparity buffer -> post-processing
wire                        disp_valid;
wire    [DISP_BITS_R-1:0]   disp_disp;
wire    [ SAD_BITS_R-1:0]   disp_sad;
wire    [ SAD_BITS_R-1:0]   disp_lo;
wire    [ SAD_BITS_R-1:0]   disp_hi;
wire    [ SAD_BITS_R-1:0]   disp_thresh;
wire    [     MULT_R -1:0]  disp_filtered;

// post-processing -> backend
wire                        post_valid;
wire    [     MULT_R -1:0]  post_filtered;
wire    [DISP_BITS_SR-1:0]  post_disp;
wire    [ SAD_BITS_R -1:0]  post_sad;

// backend -> frontend
wire                        back_busy;


// ** front-end **

dlsc_stereobm_frontend #(
    .IMG_WIDTH      ( IMG_WIDTH ),
    .IMG_HEIGHT     ( IMG_HEIGHT ),
    .DISP_BITS      ( DISP_BITS ),
    .DISPARITIES    ( DISPARITIES ),
    .TEXTURE        ( TEXTURE ),
    .TEXTURE_CONST  ( DATA_MAX/2 ),
    .MULT_D         ( MULT_D ),
    .MULT_R         ( MULT_R ),
    .SAD            ( SAD ),
    .DATA           ( DATA ),
    .PIPELINE_WR    ( PIPELINE_BRAM_WR )
) dlsc_stereobm_frontend_inst (
    .clk                ( clk ),
    .rst                ( rst ),
    .in_ready           ( in_ready ),
    .in_valid           ( in_valid ),
    .in_left            ( in_left ),
    .in_right           ( in_right ),
    .out_right_valid    ( front_right_valid ),
    .out_valid          ( front_valid ),
    .out_first          ( front_first ),
    .out_left           ( front_left ),
    .out_right          ( front_right ),
    .back_busy          ( back_busy ),
    .back_valid         ( back_valid ),
    .back_left          ( back_left ),
    .back_right         ( back_right )
);


// ** pipeline **

dlsc_stereobm_multipipe #(
    .MULT_D         ( MULT_D ),
    .MULT_R         ( MULT_R ),
    .SAD            ( SAD ),
    .DATA           ( DATA ),
    .SAD_BITS       ( SAD_BITS ),
    .PIPELINE_IN    ( PIPELINE_FANOUT )
) dlsc_stereobm_multipipe_inst (
    .clk                ( clk ),
    .rst                ( rst ),
    .in_right_valid     ( front_right_valid ),
    .in_valid           ( front_valid ),
    .in_first           ( front_first ),
    .in_left            ( front_left ),
    .in_right           ( front_right ),
    .out_valid          ( pipe_valid ),
    .out_sad            ( pipe_sad )
);


// ** disparity buffer **

dlsc_stereobm_disparity #(
    .IMG_WIDTH      ( IMG_WIDTH ),
    .DISP_BITS      ( DISP_BITS ),
    .DISPARITIES    ( DISPARITIES ),
    .TEXTURE        ( TEXTURE ),
    .SUB_BITS       ( SUB_BITS ),
    .UNIQUE_MUL     ( UNIQUE_MUL ),
    .MULT_D         ( MULT_D ),
    .MULT_R         ( MULT_R ),
    .SAD            ( SAD ),
    .SAD_BITS       ( SAD_BITS ),
    .PIPELINE_RD    ( PIPELINE_BRAM_RD ),
    .PIPELINE_WR    ( PIPELINE_BRAM_WR ),
    .PIPELINE_LUT4  ( PIPELINE_LUT4 )
) dlsc_stereobm_disparity_inst (
    .clk                ( clk ),
    .rst                ( rst ),
    .in_valid           ( pipe_valid ),
    .in_sad             ( pipe_sad ),
    .out_valid          ( disp_valid ),
    .out_disp           ( disp_disp ),
    .out_sad            ( disp_sad ),
    .out_lo             ( disp_lo ),
    .out_hi             ( disp_hi ),
    .out_thresh         ( disp_thresh ),
    .out_filtered       ( disp_filtered )
);


// ** post-processing **

dlsc_stereobm_postprocess #(
    .DISP_BITS      ( DISP_BITS ),
    .DISPARITIES    ( DISPARITIES ),
    .SUB_BITS       ( SUB_BITS ),
    .SUB_BITS_EXTRA ( SUB_BITS_EXTRA ),
    .UNIQUE_MUL     ( UNIQUE_MUL ),
    .UNIQUE_DIV     ( UNIQUE_DIV ),
    .MULT_R         ( MULT_R ),
    .SAD_BITS       ( SAD_BITS ),
//    .PIPELINE_LUT4  ( 1 ) // sub-pixel divider was giving trouble on Spartan-6
    .PIPELINE_LUT4  ( PIPELINE_LUT4 )
) dlsc_stereobm_postprocess_inst (
    .clk                ( clk ),
    .rst                ( rst ),
    .in_valid           ( disp_valid ),
    .in_disp            ( disp_disp ),
    .in_sad             ( disp_sad ),
    .in_lo              ( disp_lo ),
    .in_hi              ( disp_hi ),
    .in_thresh          ( disp_thresh ),
    .in_filtered        ( disp_filtered ),
    .out_valid          ( post_valid ),
    .out_filtered       ( post_filtered ),
    .out_disp           ( post_disp ),
    .out_sad            ( post_sad )
);


// ** back-end **

dlsc_stereobm_backend #(
    .IMG_WIDTH      ( IMG_WIDTH ),
    .IMG_HEIGHT     ( IMG_HEIGHT ),
    .DISP_BITS      ( DISP_BITS_S ),
    .DISPARITIES    ( DISPARITIES ),
    .MULT_R         ( MULT_R ),
    .SAD            ( SAD ),
    .DATA           ( DATA ),
    .SAD_BITS       ( SAD_BITS )
) dlsc_stereobm_backend_inst (
    .clk                ( clk ),
    .rst                ( rst ),
    .in_valid           ( post_valid ),
    .in_filtered        ( post_filtered ),
    .in_disp            ( post_disp ),
    .in_sad             ( post_sad ),
    .back_valid         ( back_valid ),
    .back_left          ( back_left ),
    .back_right         ( back_right ),
    .out_disp_valid     ( out_disp_valid ),
    .out_disp_data      ( out_disp_data ),
    .out_disp_masked    ( out_disp_masked ),
    .out_disp_filtered  ( out_disp_filtered ),
    .out_img_valid      ( out_img_valid ),
    .out_img_left       ( out_img_left ),
    .out_img_right      ( out_img_right )
);

assign back_busy = out_busy;


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"
integer cycle_cnt;
integer in_px_cnt;
integer in_first_cnt;
integer in_first_cnt_sav;
integer out_px_cnt;
integer out_first_cnt;
integer out_last_cnt;
always @(posedge clk) begin
    if(rst) begin
        cycle_cnt       = 0;
        in_px_cnt       = 0;
        in_first_cnt    = 0;
        in_first_cnt_sav= 0;
        out_px_cnt      = 0;
        out_first_cnt   = 0;
        out_last_cnt    = 0;
    end else begin
        if(in_valid && in_ready) begin
            // input pixel transferred
            if(in_px_cnt == 0) begin
                // first input pixel of frame
                in_first_cnt    = cycle_cnt;
            end
            if(in_px_cnt == ((IMG_WIDTH*IMG_HEIGHT/MULT_R)-1)) begin
                // last input pixel of frame
                in_px_cnt       = 0;
            end else begin
                in_px_cnt       = in_px_cnt + 1;
            end
        end
//        if(out_valid && out_ready) begin
        if(out_disp_valid) begin
            // output pixel transferred
            if(out_px_cnt == 0) begin
                // first output pixel of frame
                in_first_cnt_sav=in_first_cnt;
                out_first_cnt   = cycle_cnt;
            end
            if(out_px_cnt == (IMG_WIDTH*IMG_HEIGHT/MULT_R)-1) begin
                // last output pixel of frame
                out_last_cnt    = cycle_cnt;
                report;
                out_px_cnt      = 0;
            end else begin
                out_px_cnt      = out_px_cnt + 1;
            end
        end
        cycle_cnt       = cycle_cnt + 1;
    end
end

task report;
begin
    `dlsc_info("** frame completed **");
    `dlsc_info("cycles from first input pixel to first output pixel: %0d", (out_first_cnt-in_first_cnt_sav));
    `dlsc_info("cycles from first input pixel to last output pixel: %0d", (out_last_cnt-in_first_cnt_sav));
    dlsc_stereobm_frontend_inst.report;
    dlsc_stereobm_multipipe_inst.report;
    dlsc_stereobm_backend_inst.report;
end
endtask
`include "dlsc_sim_bot.vh"
`endif


endmodule

