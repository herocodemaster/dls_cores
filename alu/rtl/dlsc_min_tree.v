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
// Finds lowest value out of an arbitrary number of inputs.
// Pipeline delay is: 2 + ($clog2(INPUTS)-1) * (PIPELINE>0?2:1)
// ..that is: 2 cycles for last stage, and 1 or 2 cycles for intermediate
//            stages (depending on PIPELINE)

module dlsc_min_tree #(
    parameter DATA      = 32,
    parameter ID        = 8,
    parameter META      = 1,
    parameter INPUTS    = 9,
    parameter PIPELINE  = 1
) (
    input   wire                            clk,
    input   wire                            rst,
    
    input   wire                            in_valid,
    input   wire    [META-1:0]              in_meta,
    input   wire    [(  ID*INPUTS)-1:0]     in_id,
    input   wire    [(DATA*INPUTS)-1:0]     in_data,
    
    output  wire                            out_valid,
    output  wire    [META-1:0]              out_meta,
    output  wire    [  ID-1:0]              out_id,
    output  wire    [DATA-1:0]              out_data
);

///* verilator tracing_off */

`include "dlsc_clog2.vh"
localparam LEVELS       = `dlsc_clog2(INPUTS);
localparam INPUTS_M2    = INPUTS + (INPUTS%2);

localparam OUT_CYCLE    = 2 + (LEVELS-1) * (PIPELINE>0?2:1);

`define DLSC_LEVEL_INPUTS  ( (INPUTS+(2**(l-1))-1) / (2**(l-1)) )
`define DLSC_LEVEL_OUTPUTS ( (INPUTS+(2**(l  ))-1) / (2**(l  )) )

generate
    genvar l;
    genvar j;
    integer i;

    if(INPUTS > 1) begin:GEN_TREE

        // inputs/outputs for each level
        wire [(  ID*INPUTS_M2)-1:0] nodes_i [LEVELS:0];
        wire [(DATA*INPUTS_M2)-1:0] nodes_d [LEVELS:0];

        // output comes from last level
        assign out_id   = nodes_i[LEVELS][ 0 +:   ID ];
        assign out_data = nodes_d[LEVELS][ 0 +: DATA ];

        // inputs go to first level
        for(j=0;j<INPUTS;j=j+1) begin:GEN_INPUTS
            assign nodes_i[0][ (j*  ID) +:   ID ] = in_id  [ (j*  ID) +:   ID ];
            assign nodes_d[0][ (j*DATA) +: DATA ] = in_data[ (j*DATA) +: DATA ];
        end
        for(j=INPUTS;j<INPUTS_M2;j=j+1) begin:GEN_INPUTS_REM
            assign nodes_i[0][ (j*  ID) +:   ID ] = {ID{1'b0}};
            assign nodes_d[0][ (j*DATA) +: DATA ] = {DATA{1'b0}};
        end

        // comparators
        for(l=1;l<=LEVELS;l=l+1) begin:GEN_LEVELS
            for(j=0;j<`DLSC_LEVEL_INPUTS/2;j=j+1) begin:GEN_SLICES

                dlsc_compex #(
                    .DATA           ( DATA ),
                    .ID             ( ID ),
                    .PIPELINE       ( (l==LEVELS||PIPELINE>0) ? 1 : 0 )
                ) dlsc_compex_inst (
                    .clk            ( clk ),
                    .in_id0         ( nodes_i[l-1][ (((j*2)+0)*  ID) +:   ID ] ),
                    .in_data0       ( nodes_d[l-1][ (((j*2)+0)*DATA) +: DATA ] ),
                    .in_id1         ( nodes_i[l-1][ (((j*2)+1)*  ID) +:   ID ] ),
                    .in_data1       ( nodes_d[l-1][ (((j*2)+1)*DATA) +: DATA ] ),
                    .out_id0        ( nodes_i[l  ][ (  j      *  ID) +:   ID ] ),
                    .out_data0      ( nodes_d[l  ][ (  j      *DATA) +: DATA ] ),
                    .out_id1        (  ),
                    .out_data1      (  )
                );

            end
            for(j=`DLSC_LEVEL_INPUTS/2;j<`DLSC_LEVEL_OUTPUTS;j=j+1) begin:GEN_SLICES_PASSTHROUGH

                // odd number of inputs to this level; passthrough last one

                dlsc_pipedelay #(
                    .DATA           ( DATA ),
                    .DELAY          ( (l==LEVELS||PIPELINE>0) ? 2 : 1 )
                ) dlsc_pipedelay_inst_data (
                    .clk            ( clk ),
                    .in_data        ( nodes_d[l-1][ (((j*2)+0)*DATA) +: DATA ] ),
                    .out_data       ( nodes_d[l  ][ (  j      *DATA) +: DATA ] )
                );

                dlsc_pipedelay #(
                    .DATA           ( ID ),
                    .DELAY          ( (l==LEVELS||PIPELINE>0) ? 2 : 1 )
                ) dlsc_pipedelay_inst_id (
                    .clk            ( clk ),
                    .in_data        ( nodes_i[l-1][ (((j*2)+0)*  ID) +:   ID ] ),
                    .out_data       ( nodes_i[l  ][ (  j      *  ID) +:   ID ] )
                );
            
            end
            for(j=`DLSC_LEVEL_OUTPUTS;j<INPUTS_M2;j=j+1) begin:GEN_SLICES_REM
                assign nodes_i[l][ (j*  ID) +:   ID ] = {  ID{1'b0}};
                assign nodes_d[l][ (j*DATA) +: DATA ] = {DATA{1'b0}};
            end
        end

        // delay valid/meta
        dlsc_pipedelay_valid #(
            .DATA   ( META ),
            .DELAY  ( OUT_CYCLE )
        ) dlsc_pipedelay_valid_inst (
            .clk        ( clk ),
            .rst        ( rst ),
            .in_valid   ( in_valid ),
            .in_data    ( in_meta ),
            .out_valid  ( out_valid ),
            .out_data   ( out_meta )
        );

    end else begin:GEN_PASSTHROUGH
        // only 1 input; just passthrough values
        assign out_valid    = in_valid;
        assign out_meta     = in_meta;
        assign out_id       = in_id;
        assign out_data     = in_data;
    end

endgenerate

`undef DLSC_LEVEL_INPUTS
`undef DLSC_LEVEL_OUTPUTS

///* verilator tracing_on */

//`ifdef DLSC_SIMULATION
//
//wire [DATA-1:0] dbg_inputs[INPUTS-1:0];
//wire [DATA-1:0] dbg_outputs[0:0];
//
//generate
//    for(j=0;j<INPUTS;j=j+1) begin:GEN_DBG_INPUTS
//        assign dbg_inputs[j] = in_data[ (j*DATA) +: DATA ];
//    end
//endgenerate
//
//assign dbg_outputs[0] = out_data;
//
//`endif

endmodule

