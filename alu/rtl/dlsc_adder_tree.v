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
// Sums an arbitrary number of inputs into a single output.
// Pipeline delay is $clog2(INPUTS)

module dlsc_adder_tree #(
    parameter IN_BITS   = 16,
    parameter OUT_BITS  = IN_BITS+4,
    parameter INPUTS    = 9,
    parameter META      = 4,
    // derived parameters; don't touch
    parameter IN_BITS_I = (IN_BITS*INPUTS)
) (
    input   wire                            clk,
    input   wire                            rst,
    
    input   wire                            in_valid,
    input   wire    [META-1:0]              in_meta,
    input   wire    [IN_BITS_I-1:0]         in_data,
    
    output  wire                            out_valid,
    output  wire    [META-1:0]              out_meta,
    output  wire    [OUT_BITS-1:0]          out_data
);

/* verilator tracing_off */

`include "dlsc_synthesis.vh"
`include "dlsc_clog2.vh"

localparam LEVELS       = `dlsc_clog2(INPUTS);
localparam INPAD        = OUT_BITS - IN_BITS;
localparam INPUTS_M2    = INPUTS + (INPUTS%2);

`define DLSC_LEVEL_INPUTS  ( (INPUTS+(2**(l-1))-1) / (2**(l-1)) )
`define DLSC_LEVEL_OUTPUTS ( (INPUTS+(2**(l  ))-1) / (2**(l  )) )

generate
    genvar l;
    genvar j;
    integer i;

    if(INPUTS > 1) begin:GEN_TREE

        // inputs/outputs for each level
        wire [(OUT_BITS*INPUTS_M2)-1:0] nodes [LEVELS:0];

        // output comes from last level
        assign out_data = nodes[LEVELS][ 0 +: OUT_BITS ];

        // inputs go to first level
        for(j=0;j<INPUTS;j=j+1) begin:GEN_INPUTS
            assign nodes[0][ (j*OUT_BITS) +: OUT_BITS ] = { {INPAD{1'b0}} , in_data[ (j*IN_BITS) +: IN_BITS ] };
        end
        for(j=INPUTS;j<INPUTS_M2;j=j+1) begin:GEN_INPUTS_REM
            assign nodes[0][ (j*OUT_BITS) +: OUT_BITS ] = {OUT_BITS{1'b0}};
        end

        // adders
        for(l=1;l<=LEVELS;l=l+1) begin:GEN_LEVELS
            for(j=0;j<`DLSC_LEVEL_INPUTS/2;j=j+1) begin:GEN_SLICES
                `DLSC_NO_SHREG reg  [OUT_BITS-1:0] sum;
                wire [OUT_BITS-1:0] in0 = nodes[l-1][ (((j*2)+0)*OUT_BITS) +: OUT_BITS ];
                wire [OUT_BITS-1:0] in1 = nodes[l-1][ (((j*2)+1)*OUT_BITS) +: OUT_BITS ];
                always @(posedge clk) begin
                    sum <= in0 + in1;
                end
                assign nodes[l][ (j*OUT_BITS) +: OUT_BITS ] = sum;
            end
            for(j=`DLSC_LEVEL_INPUTS/2;j<`DLSC_LEVEL_OUTPUTS;j=j+1) begin:GEN_SLICES_PASSTHROUGH
                // odd number of inputs to this level; passthrough last one
                reg  [OUT_BITS-1:0] sum;
                wire [OUT_BITS-1:0] in0 = nodes[l-1][ (((j*2)+0)*OUT_BITS) +: OUT_BITS ];
                always @(posedge clk) begin
                    sum <= in0;
                end
                assign nodes[l][ (j*OUT_BITS) +: OUT_BITS ] = sum;
            end
            for(j=`DLSC_LEVEL_OUTPUTS;j<INPUTS_M2;j=j+1) begin:GEN_SLICES_REM
                assign nodes[l][ (j*OUT_BITS) +: OUT_BITS ] = {OUT_BITS{1'b0}};
            end
        end

        // delay valid/meta
        dlsc_pipedelay_valid #(
            .DATA   ( META ),
            .DELAY  ( LEVELS )
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
        assign out_data     = {{INPAD{1'b0}},in_data};
    end

endgenerate

`undef DLSC_LEVEL_INPUTS
`undef DLSC_LEVEL_OUTPUTS

/* verilator tracing_on */

//`ifdef DLSC_SIMULATION
//
//wire [IN_BITS-1:0]  dbg_inputs[INPUTS-1:0];
//wire [OUT_BITS-1:0] dbg_outputs[0:0];
//
//generate
//    for(j=0;j<INPUTS;j=j+1) begin:GEN_DBG_INPUTS
//        assign dbg_inputs[j] = in_data[ (j*IN_BITS) +: IN_BITS ];
//    end
//endgenerate
//
//assign dbg_outputs[0] = out_data;
//
//`endif

endmodule

