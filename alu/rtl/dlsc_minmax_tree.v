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
// Finds lowest and highest values out of an arbitrary number of inputs.
// TODO: depends on removed legacy modules; needs updating

module dlsc_minmax_tree #(
    parameter DATA      = 32,
    parameter ID        = 8,
    parameter META      = 1,
    parameter INPUTS    = 9
) (
    input   wire                            clk,
    input   wire                            rst,
    
    input   wire    [META-1:0]              in_meta,
    input   wire    [(ID*INPUTS)-1:0]       in_id,
    input   wire    [(DATA*INPUTS)-1:0]     in_data,

    output  reg     [META-1:0]              out_meta,
    output  reg     [ID-1:0]                out_min_id,
    output  reg     [DATA-1:0]              out_min_data,
    output  reg     [ID-1:0]                out_max_id,
    output  reg     [DATA-1:0]              out_max_data
);

localparam OUTPUTS = (INPUTS+1)/2;
localparam INPUTS_M2 = OUTPUTS*2;

wire [DATA-1:0] inputs_d[INPUTS_M2-1:0];
wire [ID-1:0]   inputs_i[INPUTS_M2-1:0];

wire [META-1:0]             outputs_m;
wire [(DATA*OUTPUTS)-1:0]   outputs_mind;
wire [(  ID*OUTPUTS)-1:0]   outputs_mini;
wire [(DATA*OUTPUTS)-1:0]   outputs_maxd;
wire [(  ID*OUTPUTS)-1:0]   outputs_maxi;

generate
    genvar j;
    for(j=0;j<INPUTS;j=j+1) begin:GEN_INPUTS
        assign inputs_d[j] = in_data[(j*DATA)+DATA-1:(j*DATA)];
        assign inputs_i[j] = in_id[  (j*  ID)+  ID-1:(j*  ID)];
    end

    for(j=INPUTS;j<INPUTS_M2;j=j+1) begin:GEN_INPUTS_REM
        assign inputs_d[j] = in_data[((j-1)*DATA)+DATA-1:((j-1)*DATA)];
        assign inputs_i[j] = in_id[  ((j-1)*  ID)+  ID-1:((j-1)*  ID)];
    end
        
    dlsc_minmax_slice #(
        .DATA   ( DATA ),
        .ID     ( ID ),
        .META   ( META )
    ) dlsc_minmax_slice_inst0 (
        .clk            ( clk ),
        .rst            ( rst ),
        .in_meta        ( in_meta ),
        .in_data0       ( inputs_d[0] ),
        .in_id0         ( inputs_i[0] ),
        .in_data1       ( inputs_d[1] ),
        .in_id1         ( inputs_i[1] ),
        .out_meta       ( outputs_m ),
        .out_min_data   ( outputs_mind[DATA-1:0] ),
        .out_min_id     ( outputs_mini[  ID-1:0] ),
        .out_max_data   ( outputs_maxd[DATA-1:0] ),
        .out_max_id     ( outputs_maxi[  ID-1:0] )
    );

    for(j=1;j<OUTPUTS;j=j+1) begin:GEN_SLICES
        dlsc_minmax_slice #(
            .DATA   ( DATA ),
            .ID     ( ID ),
            .META   ( 1 )
        ) dlsc_minmax_slice_inst (
            .clk            ( clk ),
            .rst            ( rst ),
            .in_meta        ( 1'b0 ),
            .in_data0       ( inputs_d[(j*2)] ),
            .in_id0         ( inputs_i[(j*2)] ),
            .in_data1       ( inputs_d[(j*2)+1] ),
            .in_id1         ( inputs_i[(j*2)+1] ),
            .out_meta       (  ),
            .out_min_data   ( outputs_mind[(j*DATA)+DATA-1:(j*DATA)] ),
            .out_min_id     ( outputs_mini[(j*  ID)+  ID-1:(j*  ID)] ),
            .out_max_data   ( outputs_maxd[(j*DATA)+DATA-1:(j*DATA)] ),
            .out_max_id     ( outputs_maxi[(j*  ID)+  ID-1:(j*  ID)] )
        );
    end

    if(OUTPUTS == 1) begin:GEN_FINAL
        assign out_meta         = outputs_m;
        assign out_min_id       = outputs_mini;
        assign out_min_data     = outputs_mind;
        assign out_max_id       = outputs_maxi;
        assign out_max_data     = outputs_maxd;
    end
    else begin:GEN_RECURSE
        dlsc_min_tree #(
            .DATA   ( DATA ),
            .ID     ( ID ),
            .META   ( META ),
            .INPUTS ( OUTPUTS )
        ) dlsc_min_tree_inst (
            .clk            ( clk ),
            .rst            ( rst ),
            .in_meta        ( outputs_m ),
            .in_id          ( outputs_mini ),
            .in_data        ( outputs_mind ),
            .out_meta       ( out_meta ),
            .out_id         ( out_min_id ),
            .out_data       ( out_min_data ),
        );
        dlsc_max_tree #(
            .DATA   ( DATA ),
            .ID     ( ID ),
            .META   ( 1 ),
            .INPUTS ( OUTPUTS )
        ) dlsc_max_tree_inst (
            .clk            ( clk ),
            .rst            ( rst ),
            .in_meta        (  ),
            .in_id          ( outputs_maxi ),
            .in_data        ( outputs_maxd ),
            .out_meta       (  ),
            .out_id         ( out_max_id ),
            .out_data       ( out_max_data )
        );
    end
endgenerate

endmodule

