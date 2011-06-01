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
// Post-processing stage in the pipeline. Implements:
// - sub-pixel interpolation (see dlsc_stereobm_postprocess_subpixel)
// - uniqueness ratio filtering (see dlsc_stereobm_postprocess_uniqueness)
// - merges uniqueness filter results with results from previous pipeline
//   stage (e.g. texture filtering).

module dlsc_stereobm_postprocess #(
    parameter DISP_BITS     = 6,
    parameter DISPARITIES   = (2**DISP_BITS),
    parameter SUB_BITS      = 4,
    parameter SUB_BITS_EXTRA= 4,
    parameter UNIQUE_MUL    = 1,
    parameter UNIQUE_DIV    = 4,
    parameter MULT_R        = 3,
    parameter SAD_BITS      = 16,
    parameter PIPELINE_LUT4 = 0,
    // derived parameters; don't touch
    parameter DISP_BITS_R   = (DISP_BITS*MULT_R),
    parameter SAD_BITS_R    = (SAD_BITS*MULT_R),
    parameter DISP_BITS_S   = (DISP_BITS+SUB_BITS),
    parameter DISP_BITS_SR  = (DISP_BITS_S*MULT_R)
) (
    // system
    input   wire                        clk,
    input   wire                        rst,

    // inputs from disparity buffer
    input   wire                        in_valid,
    input   wire    [DISP_BITS_R -1:0]  in_disp,
    input   wire    [ SAD_BITS_R -1:0]  in_sad,
    // inputs in sub-pixel mode
    input   wire    [ SAD_BITS_R -1:0]  in_lo,
    input   wire    [ SAD_BITS_R -1:0]  in_hi,
    // inputs in uniqueness mode
    input   wire    [ SAD_BITS_R -1:0]  in_thresh,
    // inputs for texture filtering
    input   wire    [     MULT_R -1:0]  in_filtered,

    // output
    output  wire                        out_valid,
    output  reg     [     MULT_R -1:0]  out_filtered,
    output  wire    [DISP_BITS_SR-1:0]  out_disp,
    output  wire    [ SAD_BITS_R -1:0]  out_sad
);

localparam SUB_CYCLE    = SUB_BITS>0    ? (3 + (PIPELINE_LUT4>0?2:1) * (SUB_BITS+SUB_BITS_EXTRA)) : 0;
localparam UNIQUE_CYCLE = UNIQUE_MUL>0  ? 7 : 0;

localparam OUT_CYCLE    = ((SUB_CYCLE>UNIQUE_CYCLE) ? SUB_CYCLE : UNIQUE_CYCLE) + 1; // use longest as output cycle

localparam OUT_CYCLE_FILTER = (OUT_CYCLE - 1); // 1 cycle early, so we can register combined filter output

// delay in_filtered and combine with uniqueness filtering at output
wire [MULT_R-1:0] out_in_filtered;
wire [MULT_R-1:0] out_unique_filtered;
dlsc_pipedelay #(
    .DATA       ( MULT_R ),
    .DELAY      ( OUT_CYCLE_FILTER )
) dlsc_pipedelay_inst_text (
    .clk        ( clk ),
    .in_data    ( in_filtered ),
    .out_data   ( out_in_filtered )
);

always @(posedge clk) begin
    out_filtered <= out_in_filtered | out_unique_filtered;
end

generate
    genvar j;

    if(UNIQUE_MUL>0) begin:GEN_UNIQUE
        for(j=0;j<MULT_R;j=j+1) begin:GEN_UNIQUE_LOOP

            dlsc_stereobm_postprocess_uniqueness #(
                .DISP_BITS      ( DISP_BITS ),
                .DISPARITIES    ( DISPARITIES ),
                .UNIQUE_MUL     ( UNIQUE_MUL ),
                .UNIQUE_DIV     ( UNIQUE_DIV ),
                .SAD_BITS       ( SAD_BITS ),
                .OUT_CYCLE      ( OUT_CYCLE_FILTER )
            ) dlsc_stereobm_postprocess_uniqueness_inst (
                .clk            ( clk ),
                .in_sad         ( in_sad    [ (j* SAD_BITS) +:  SAD_BITS ] ),
                .in_thresh      ( in_thresh [ (j* SAD_BITS) +:  SAD_BITS ] ),
                .out_filtered   ( out_unique_filtered[j] )
            );

        end
    end else begin:GEN_NOUNIQUE

        assign out_unique_filtered = {MULT_R{1'b0}};

    end

    if(SUB_BITS>0) begin:GEN_SUB
        for(j=0;j<MULT_R;j=j+1) begin:GEN_SUB_LOOP

            dlsc_stereobm_postprocess_subpixel #(
                .DISP_BITS      ( DISP_BITS ),
                .DISPARITIES    ( DISPARITIES ),
                .SUB_BITS       ( SUB_BITS ),
                .SUB_BITS_EXTRA ( SUB_BITS_EXTRA ),
                .SAD_BITS       ( SAD_BITS ),
                .PIPELINE_LUT4  ( PIPELINE_LUT4 ),
                .OUT_CYCLE      ( OUT_CYCLE )
            ) dlsc_stereobm_postprocess_subpixel_inst (
                .clk            ( clk ),
                .in_disp        ( in_disp [ (j*DISP_BITS  ) +: DISP_BITS   ] ),
                .in_sad         ( in_sad  [ (j* SAD_BITS  ) +:  SAD_BITS   ] ),
                .in_lo          ( in_lo   [ (j* SAD_BITS  ) +:  SAD_BITS   ] ),
                .in_hi          ( in_hi   [ (j* SAD_BITS  ) +:  SAD_BITS   ] ),
                .out_disp       ( out_disp[ (j*DISP_BITS_S) +: DISP_BITS_S ] )
            );

        end               
    end else begin:GEN_NOSUB

        dlsc_pipedelay #(
            .DATA       ( DISP_BITS_R  ),
            .DELAY      ( OUT_CYCLE )
        ) dlsc_pipedelay_inst_disp (
            .clk        ( clk ),
            .in_data    (  in_disp ),
            .out_data   ( out_disp )
        );

    end

endgenerate

// delay valid to out
dlsc_pipedelay_rst #(
    .DATA       ( 1 ),
    .DELAY      ( OUT_CYCLE ),
    .RESET      ( 1'b0 )
) dlsc_pipedelay_rst_inst_valid (
    .clk        ( clk ),
    .rst        ( rst ),
    .in_data    ( in_valid ),
    .out_data   ( out_valid )
);

// delay in_sad to out_sad
dlsc_pipedelay #(
    .DATA       ( SAD_BITS_R ),
    .DELAY      ( OUT_CYCLE )
) dlsc_pipedelay_inst_sad (
    .clk        ( clk ),
    .in_data    ( in_sad ),
    .out_data   ( out_sad )
);

endmodule

