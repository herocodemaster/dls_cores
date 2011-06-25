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
// Wrapper around dlsc_stereobm_core that includes extra asynchronous
// buffering to make the core more user-friendly.
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
//  mem/rtl/dlsc_pipedelay.v
//  mem/rtl/dlsc_pipedelay_clken.v
//  mem/rtl/dlsc_pipedelay_rst.v
//  mem/rtl/dlsc_pipedelay_valid.v
//  mem/rtl/dlsc_pipereg.v
//  mem/rtl/dlsc_ram_dp.v
//  mem/rtl/dlsc_ram_dp_slice.v
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
//  sync/rtl/dlsc_domaincross.v
//  sync/rtl/dlsc_domaincross_slice.v
//  sync/rtl/dlsc_syncflop.v
//  sync/rtl/dlsc_syncflop_slice.v

module dlsc_stereobm_buffered #(

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

    // output options
    parameter OUT_LEFT          = 1,                // enable out_left
    parameter OUT_RIGHT         = 1,                // enable out_right

    // parallelization
    parameter MULT_D            = 8,                // number of disparities to compute in parallel (DISPARITIES must be integer multiple of this)
    parameter MULT_R            = 2,                // number of rows to run in parallel (IMG_HEIGHT and SAD_WINDOW/2 must be integer multiple of this)

    // synthesis performance tuning parameters
    parameter PIPELINE_BRAM_RD  = 1,                // needed by most architectures
    parameter PIPELINE_BRAM_WR  = 1,                // needed by Virtex-6 (and sometimes Spartan-6)
    parameter PIPELINE_FANOUT   = 1,                // needed by Virtex-6
    parameter PIPELINE_LUT4     = 0,                // needed by Spartan-3

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
    output  wire    [DATA  -1:0]        out_left,           // left image data (delayed in_left)
    output  wire    [DATA  -1:0]        out_right           // right image data (delayed in_right)
);

`include "dlsc_synthesis.vh"
`include "dlsc_clog2.vh"

genvar j;

localparam DATA_R           = (DATA*MULT_R);                // width of whole input image data port
localparam DISP_BITS_SR     = ((DISP_BITS+SUB_BITS)*MULT_R);// width of whole output disparity data port

localparam CORE_IN          = ( 2*DATA );
localparam CORE_OUT_DISP    = ( DISP_BITS_S + 2 );
localparam CORE_OUT_IMG     = ( ((OUT_LEFT>0)?DATA:0) + ((OUT_RIGHT>0)?DATA:0) );
localparam CORE_OUT         = ( CORE_OUT_DISP + CORE_OUT_IMG );

localparam IN_BUF_DEPTH     = 2**(`dlsc_clog2(IMG_WIDTH)); // round to power-of-2

localparam ALMOST_FULL      = 128; // must be enough to survive worst-case pipeline stall (50~100 cycles)

localparam OUT_BUF_DEPTH    = 2**(`dlsc_clog2(IMG_WIDTH + ALMOST_FULL)); // round to power-of-2


// ** reset synchronization **

wire int_rst;
wire core_rst;

dlsc_rstsync #(
    .DOMAINS    ( 2 )
) dlsc_rstsync_inst (
    .rst_in     ( rst ),
    .clk        ( {     clk, core_clk } ),
    .rst_out    ( { int_rst, core_rst } )
);


// ** input buffering **

wire                            core_in_ready;
wire                            core_in_valid;
wire [(CORE_IN*MULT_R)-1:0]     core_in;

dlsc_rowbuffer #(
    .ROW_WIDTH          ( IMG_WIDTH ),
    .BUF_DEPTH          ( IN_BUF_DEPTH ),
    .IN_ROWS            ( 1 ),
    .OUT_ROWS           ( MULT_R ),
    .DATA               ( CORE_IN )
) dlsc_rowbuffer_inst_in (
    .in_clk             ( clk ),
    .in_rst             ( int_rst ),
    .in_ready           ( in_ready ),
    .in_valid           ( in_valid ),
    .in_data            ( {
        in_left,
        in_right } ),
    .in_almost_full     (  ),
    .out_clk            ( core_clk ),
    .out_rst            ( core_rst ),
    .out_ready          ( core_in_ready ),
    .out_valid          ( core_in_valid ),
    .out_data           ( core_in )
);

// rearrange inputs
wire [DATA_R-1:0]       core_in_left;
wire [DATA_R-1:0]       core_in_right;

generate
    for(j=0;j<MULT_R;j=j+1) begin:GEN_CORE_IN
        assign {
            core_in_left [ (j*DATA) +: DATA ],
            core_in_right[ (j*DATA) +: DATA ] } = core_in[ (j*CORE_IN) +: CORE_IN ];
    end
endgenerate


// ** output buffering - disparity data **

wire                                core_out_disp_busy;

wire                                core_out_disp_ready;
wire                                core_out_disp_valid;

wire [DISP_BITS_SR-1:0]             core_out_disp_data;
wire [MULT_R-1:0]                   core_out_disp_masked;
wire [MULT_R-1:0]                   core_out_disp_filtered;

wire [(CORE_OUT_DISP*MULT_R)-1:0]   core_out_disp; // interleaved concatenation of above _data, _masked and _filtered signals

wire                                buf_out_disp_ready;
wire                                buf_out_disp_valid;

wire [DISP_BITS_S-1:0]              buf_out_disp_data;
wire                                buf_out_disp_masked;
wire                                buf_out_disp_filtered;

dlsc_rowbuffer #(
    .ROW_WIDTH          ( IMG_WIDTH ),
    .BUF_DEPTH          ( OUT_BUF_DEPTH ),
    .IN_ROWS            ( MULT_R ),
    .OUT_ROWS           ( 1 ),
    .DATA               ( CORE_OUT_DISP ),
    .ALMOST_FULL        ( ALMOST_FULL )
) dlsc_rowbuffer_inst_out_disp (
    .in_clk             ( core_clk ),
    .in_rst             ( core_rst ),
    .in_ready           ( core_out_disp_ready ),
    .in_valid           ( core_out_disp_valid ),
    .in_data            ( core_out_disp ),
    .in_almost_full     ( core_out_disp_busy ),
    .out_clk            ( clk ),
    .out_rst            ( int_rst ),
    .out_ready          ( buf_out_disp_ready ),
    .out_valid          ( buf_out_disp_valid ),
    .out_data           ( {
        buf_out_disp_data,
        buf_out_disp_masked,
        buf_out_disp_filtered } )
);

// rearrange outputs
generate
    for(j=0;j<MULT_R;j=j+1) begin:GEN_CORE_OUT_DISP
        assign core_out_disp[ (j*CORE_OUT_DISP) +: CORE_OUT_DISP ] = {
            core_out_disp_data    [ (j*DISP_BITS_S) +: DISP_BITS_S ],
            core_out_disp_masked  [  j                             ],
            core_out_disp_filtered[  j                             ] };
    end
endgenerate


// ** output buffering - image data **

wire                                core_out_img_ready;
wire                                core_out_img_valid;

wire [DATA_R-1:0]                   core_out_img_left;
wire [DATA_R-1:0]                   core_out_img_right;

generate
    if(OUT_LEFT>0 || OUT_RIGHT>0) begin:GEN_OUT_IMG

        wire [(CORE_OUT_IMG*MULT_R)-1:0]    core_out_img;   // interleaved concatenation of above left/right signals

        wire                                buf_out_img_ready;
        wire                                buf_out_img_valid;
        
        wire [CORE_OUT_IMG-1:0]             buf_out_img;

        dlsc_rowbuffer #(
            .ROW_WIDTH          ( IMG_WIDTH ),
            .BUF_DEPTH          ( OUT_BUF_DEPTH ),
            .IN_ROWS            ( MULT_R ),
            .OUT_ROWS           ( 1 ),
            .DATA               ( CORE_OUT_IMG )
        ) dlsc_rowbuffer_inst_out_img (
            .in_clk             ( core_clk ),
            .in_rst             ( core_rst ),
            .in_ready           ( core_out_img_ready ),
            .in_valid           ( core_out_img_valid ),
            .in_data            ( core_out_img ),
            .in_almost_full     (  ),
            .out_clk            ( clk ),
            .out_rst            ( int_rst ),
            .out_ready          ( buf_out_img_ready ),
            .out_valid          ( buf_out_img_valid ),
            .out_data           ( buf_out_img )
        );

        wire                                buf_out_valid;
        wire                                buf_out_ready;

        // can only be ready when both are valid
        assign buf_out_valid        = buf_out_disp_valid && buf_out_img_valid;
        assign buf_out_disp_ready   = buf_out_ready && buf_out_img_valid;
        assign buf_out_img_ready    = buf_out_ready && buf_out_disp_valid;
        
        wire [CORE_OUT_IMG-1:0]             out_img;

        dlsc_rvh_decoupler #(
            .WIDTH      ( CORE_OUT )
        ) dlsc_rvh_decoupler_inst (
            .clk                ( clk ),
            .rst                ( int_rst ),
            .in_en              ( 1'b1 ),
            .in_ready           ( buf_out_ready ),
            .in_valid           ( buf_out_valid ),
            .in_data            ( {
                buf_out_disp_data,
                buf_out_disp_masked,
                buf_out_disp_filtered,
                buf_out_img } ),
            .out_en             ( 1'b1 ),
            .out_ready          ( out_ready ),
            .out_valid          ( out_valid ),
            .out_data           ( {
                out_disp,
                out_masked,
                out_filtered,
                out_img } )
        );

        if(OUT_LEFT>0 && OUT_RIGHT>0) begin:GEN_BOTH

            for(j=0;j<MULT_R;j=j+1) begin:GEN_CORE_OUT_IMG
                assign core_out_img[ (j*CORE_OUT_IMG) +: CORE_OUT_IMG ] = {
                    core_out_img_left [ (j*DATA) +: DATA ],
                    core_out_img_right[ (j*DATA) +: DATA ] };
            end

            assign { out_left, out_right } = out_img;

        end else if(OUT_LEFT>0) begin:GEN_LEFT

            assign core_out_img     = core_out_img_left;

            assign out_left         = out_img;
            assign out_right        = 0;

        end else begin:GEN_RIGHT

            assign core_out_img     = core_out_img_right;

            assign out_left         = 0;
            assign out_right        = out_img;

        end

    end else begin:GEN_OUT_NO_IMG

        // image data not being output; just send disparity data on its way

        assign core_out_img_ready   = 1'b1;

        assign buf_out_disp_ready   = out_ready;

        assign out_valid            = buf_out_disp_valid;
        assign out_disp             = buf_out_disp_data;
        assign out_masked           = buf_out_disp_masked;
        assign out_filtered         = buf_out_disp_filtered;

        assign out_left             = 0;
        assign out_right            = 0;

    end
endgenerate


// ** the stereo core **

dlsc_stereobm_core #(
    .DATA               ( DATA ),
    .DATA_MAX           ( DATA_MAX ),
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
    .MULT_D             ( MULT_D ),
    .MULT_R             ( MULT_R ),
    .PIPELINE_BRAM_RD   ( PIPELINE_BRAM_RD ),
    .PIPELINE_BRAM_WR   ( PIPELINE_BRAM_WR ),
    .PIPELINE_FANOUT    ( PIPELINE_FANOUT ),
    .PIPELINE_LUT4      ( PIPELINE_LUT4 )
) dlsc_stereobm_core_inst (
    .clk                ( core_clk ),
    .rst                ( core_rst ),
    .in_ready           ( core_in_ready ),
    .in_valid           ( core_in_valid ),
    .in_left            ( core_in_left ),
    .in_right           ( core_in_right ),
    .out_busy           ( core_out_disp_busy ),
    .out_disp_valid     ( core_out_disp_valid ),
    .out_disp_data      ( core_out_disp_data ),
    .out_disp_masked    ( core_out_disp_masked ),
    .out_disp_filtered  ( core_out_disp_filtered ),
    .out_img_valid      ( core_out_img_valid ),
    .out_img_left       ( core_out_img_left ),
    .out_img_right      ( core_out_img_right )
);

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @(posedge core_clk) if(!core_rst) begin
    if(core_out_disp_valid && !core_out_disp_ready) begin
        `dlsc_error("core_out_disp overflow");
    end
    if(core_out_img_valid && !core_out_img_ready) begin
        `dlsc_error("core_out_img overflow");
    end
end

`include "dlsc_sim_bot.vh"
`endif


endmodule

