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
// Sort of a catch-all for reconciling pipeline data:
// - finds best overall SAD/disparity (between all MULT_D pipes and previous-
//   best in buffer; 'sad'/'disp').. this is the only mandatory feature
// - finds 2nd-best (excluding ones adjacent to the best; 'thresh').. used
//   for uniqueness ratio checking in dlsc_stereobm_postprocess_uniqueness
// - finds SAD values for the disparities above ('sad_hi') and below ('sad_lo')
//   the best one.. used for sub-pixel interpolation in
//   dlsc_stereobm_postprocess_subpixel
// - performs texture-filtering ('filtered')
//
// This block is the top-level for this functionality. It has control/sequencing
// logic and the RAM used for the disparity row buffer (which is used for saving
// state across multiple passes).

module dlsc_stereobm_disparity #(
    parameter IMG_WIDTH     = 320,
    parameter DISP_BITS     = 6,
    parameter DISPARITIES   = (2**DISP_BITS),
    parameter TEXTURE       = 0,
    parameter SUB_BITS      = 4,
    parameter UNIQUE_MUL    = 1,
    parameter MULT_D        = 4,
    parameter MULT_R        = 3,
    parameter SAD           = 9,
    parameter SAD_BITS      = 16,
    parameter PIPELINE_RD   = 0,        // enable pipeline register on BRAM read path
    parameter PIPELINE_WR   = 0,        // enable pipeline register on BRAM write path
    parameter PIPELINE_LUT4 = 0,
    // derived parameters; don't touch
    parameter DISP_BITS_R   = (DISP_BITS  *MULT_R),
    parameter SAD_BITS_R    = ( SAD_BITS  *MULT_R),
    parameter SAD_BITS_D    = ( SAD_BITS  *MULT_D),
    parameter SAD_BITS_RD   = ( SAD_BITS_R*MULT_D)
) (
    input   wire                        clk,
    input   wire                        rst,

    // inputs from stereo pipeline
    input   wire                        in_valid,
    input   wire    [ SAD_BITS_RD-1:0]  in_sad,

    // outputs to post-processing
    output  wire                        out_valid,
    output  wire    [DISP_BITS_R -1:0]  out_disp,
    output  wire    [ SAD_BITS_R -1:0]  out_sad,
    // outputs in sub-pixel mode
    output  wire    [ SAD_BITS_R -1:0]  out_lo,
    output  wire    [ SAD_BITS_R -1:0]  out_hi,
    // outputs in uniqueness mode
    output  wire    [ SAD_BITS_R -1:0]  out_thresh,
    // outputs for texture filtering
    output  wire    [     MULT_R -1:0]  out_filtered
);

`include "dlsc_clog2.vh"

// number of valid pixels that make it to the end
localparam END_WIDTH        = IMG_WIDTH - (DISPARITIES-1) - (SAD-1);
localparam END_WIDTH_BITS   = `dlsc_clog2(END_WIDTH);
    
localparam LOHI_EN          = (SUB_BITS>0||UNIQUE_MUL>0);
localparam BUF_BITS         = DISP_BITS + (1 + (LOHI_EN>0?3:0) + (UNIQUE_MUL>0?1:0)) * SAD_BITS;
localparam BUF_BITS_R       = BUF_BITS*MULT_R;

// ** compute delays to output **
localparam MULT_D_BITS  = `dlsc_clog2(MULT_D);
localparam MULT_D1_BITS = `dlsc_clog2(MULT_D+1);
localparam MULT_D3_BITS = `dlsc_clog2(MULT_D+3);

localparam CYCLE_C4 = (PIPELINE_RD>0?4:3);
localparam CYCLE_C5 = CYCLE_C4 + 1;

// cycle at output of main sorter
localparam CYCLE_CM0 = CYCLE_C5 + 2 + (MULT_D1_BITS-1) * (PIPELINE_LUT4>0?2:1);
localparam CYCLE_CM1 = CYCLE_CM0 + 1;
localparam CYCLE_CM2 = CYCLE_CM1 + (PIPELINE_LUT4>0?1:0);

// cycle at output of threshold sorter
localparam CYCLE_CT0 = CYCLE_CM2 + 2 + (MULT_D3_BITS-1) * (PIPELINE_LUT4>0?2:1);

// cycle at output of this block
localparam CYCLE_CW = UNIQUE_MUL>0 ? CYCLE_CT0 : CYCLE_CM1;


// ** control **

reg                         ctrl_first; // first pass; must ignore memory contents
reg                         ctrl_last;  // last pass; must output results
reg [DISP_BITS-1:0]         ctrl_disp;  // base disparity level for this pass
reg [DISP_BITS-1:0]         ctrl_disp_prev; // base disparity level for previous pass
reg [END_WIDTH_BITS-1:0]    ctrl_addr;
reg                         ctrl_addr_last; // ctrl_addr == (END_WIDTH-1)

/* verilator lint_off WIDTH */
always @(posedge clk) begin
    if(rst) begin
        ctrl_first      <= 1'b1;
        ctrl_last       <= 1'b0;
        ctrl_disp       <= DISPARITIES-MULT_D;            // start at maximum disparity
        ctrl_disp_prev  <= 0;
        ctrl_addr       <= 0;
        ctrl_addr_last  <= 1'b0;
    end else if(in_valid) begin
        ctrl_addr_last  <= (ctrl_addr == (END_WIDTH-2));
        if(!ctrl_addr_last) begin
            ctrl_addr       <= ctrl_addr + 1;
        end else begin
            ctrl_addr       <= 0;
            ctrl_disp_prev  <= ctrl_disp;
            if(!ctrl_last) begin
                // not on last yet; but at least done with first
                ctrl_first      <= 1'b0;
                if(TEXTURE == 0) begin
                    ctrl_last       <= (ctrl_disp == MULT_D); // on 2nd-to-last; will be on last next cycle
                end else begin
                    // need extra pass when performing texture filtering
                    ctrl_last       <= (ctrl_disp == 0     ); // on 2nd-to-last; will be on last next cycle
                end
                ctrl_disp       <= ctrl_disp - MULT_D;
            end else begin
                // on last; will be on first next cycle
                ctrl_first      <= 1'b1;
                ctrl_last       <= 1'b0;
                ctrl_disp       <= DISPARITIES-MULT_D;    // start at maximum disparity
            end
        end
    end
end
/* verilator lint_on WIDTH */


// ** pipeline delays **

wire [DISP_BITS-1:0] c3_ctrl_disp_prev;
wire                 c3_ctrl_first;
wire                 c3_ctrl_last;

dlsc_pipedelay #(
    .DATA       ( DISP_BITS + 2 ),
    .DELAY      ( (PIPELINE_RD>0) ? 3 : 2 )
) dlsc_pipedelay_inst_c3_ctrl (
    .clk        ( clk ),
    .in_data    ( {    ctrl_disp_prev ,    ctrl_first ,    ctrl_last } ),
    .out_data   ( { c3_ctrl_disp_prev , c3_ctrl_first , c3_ctrl_last } )
);

wire [DISP_BITS-1:0] cm_ctrl_disp;
dlsc_pipedelay #(
    .DATA       ( DISP_BITS ),
    .DELAY      ( CYCLE_CM0 - 1 )
) dlsc_pipedelay_inst_cm_ctrl_disp (
    .clk        ( clk ),
    .in_data    (    ctrl_disp ),
    .out_data   ( cm_ctrl_disp )
);


// ** slices **

wire [BUF_BITS_R-1:0] c3_buf_data;
wire [BUF_BITS_R-1:0] cw_buf_data;

generate
    genvar j;
    for(j=0;j<MULT_R;j=j+1) begin:GEN_SLICES

        dlsc_stereobm_disparity_slice #(
            .DISP_BITS          ( DISP_BITS ),
            .TEXTURE            ( TEXTURE ),
            .SUB_BITS           ( SUB_BITS ),
            .UNIQUE_MUL         ( UNIQUE_MUL ),
            .MULT_D             ( MULT_D ),
            .SAD_BITS           ( SAD_BITS ),
            .PIPELINE_RD        ( PIPELINE_RD ),
            .PIPELINE_LUT4      ( PIPELINE_LUT4 )
        ) dlsc_stereobm_disparity_slice_inst (
            .clk                ( clk ),
            .rst                ( rst ),
            .cm_ctrl_disp       ( cm_ctrl_disp ),
            .c3_ctrl_disp_prev  ( c3_ctrl_disp_prev ),
            .c3_ctrl_first      ( c3_ctrl_first ),
            .c3_ctrl_last       ( c3_ctrl_last ),
            .c0_pipe_sad        ( in_sad      [ (j* SAD_BITS_D) +:  SAD_BITS_D ] ),
            .c3_buf_data        ( c3_buf_data [ (j* BUF_BITS  ) +:  BUF_BITS   ] ),
            .cw_buf_data        ( cw_buf_data [ (j* BUF_BITS  ) +:  BUF_BITS   ] ),
            .cw_out_disp        ( out_disp    [ (j*DISP_BITS  ) +: DISP_BITS   ] ),
            .cw_out_sad         ( out_sad     [ (j* SAD_BITS  ) +:  SAD_BITS   ] ),
            .cw_out_lo          ( out_lo      [ (j* SAD_BITS  ) +:  SAD_BITS   ] ),
            .cw_out_hi          ( out_hi      [ (j* SAD_BITS  ) +:  SAD_BITS   ] ),
            .cw_out_thresh      ( out_thresh  [ (j* SAD_BITS  ) +:  SAD_BITS   ] ),
            .cw_out_filtered    ( out_filtered[  j                             ] )
        );

    end
endgenerate


// ** buffer **

dlsc_ram_dp #(
    .DATA           ( BUF_BITS_R ),
    .ADDR           ( END_WIDTH_BITS ),
    .DEPTH          ( END_WIDTH ),
    .PIPELINE_WR    ( CYCLE_CW + (PIPELINE_WR>0?1:0) ),
    .PIPELINE_WR_DATA ( PIPELINE_WR>0?1:0 ),
    .PIPELINE_RD    ( 3 )
) dlsc_ram_dp_inst (
    .write_clk      ( clk ),
    .write_en       ( in_valid && !ctrl_last ), // no point in writing on last pass
    .write_addr     ( ctrl_addr ),
    .write_data     ( cw_buf_data ),
    .read_clk       ( clk ),
    .read_en        ( in_valid && !ctrl_first ), // no point in reading on first pass
    .read_addr      ( ctrl_addr ),
    .read_data      ( c3_buf_data )
);


// ** output **

dlsc_pipedelay_rst #(
    .DATA       ( 1 ),
    .DELAY      ( CYCLE_CW ),
    .RESET      ( 1'b0 )
) dlsc_pipedelay_valid_inst_out_valid (
    .clk        ( clk ),
    .rst        ( rst ),
    .in_data    ( in_valid && ctrl_last ),
    .out_data   ( out_valid )
);


endmodule

