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
// Merely instantiates the MULT_D dlsc_stereobm_pipe modules required to process
// multiple disparities levels per pass. Data for the right image is cascaded
// between pipe instances (with each pipe adding a 1 cycle delay) so that each
// pipe works on a different disparity level.

module dlsc_stereobm_multipipe #(
    parameter MULT_D        = 8,
    parameter MULT_R        = 1,
    parameter SAD           = 9,
    parameter DATA          = 9,    // width of input image data
    parameter SAD_BITS      = 16,   // width of SAD output data
    parameter PIPELINE_IN   = 0,
    // derived parameters; don't touch
    parameter SAD_R         = (SAD+MULT_R-1),
    parameter SAD_BITS_R    = (SAD_BITS*MULT_R),
    parameter SAD_BITS_RD   = (SAD_BITS_R*MULT_D)
) (
    // system
    input   wire                        clk,
    input   wire                        rst,

    // from frontend row buffers
    input   wire                        in_right_valid,
    input   wire                        in_valid,
    input   wire                        in_first,
    input   wire    [(DATA*SAD_R)-1:0]  in_left,
    input   wire    [(DATA*SAD_R)-1:0]  in_right,

    // output to disparity comparator
    output  wire                        out_valid,
    output  wire    [SAD_BITS_RD-1:0]   out_sad
);

// wires for cascading pipe data
wire [(DATA*SAD_R)-1:0] cascade_right[MULT_D:0];
assign cascade_right[0] = in_right;

wire [MULT_D-1:0] out_valids;
assign out_valid = out_valids[0];

generate
    genvar j;
    genvar k;
    for(j=0;j<MULT_D;j=j+1) begin:GEN_PIPES

        wire [SAD_BITS_R-1:0] sad;

        for(k=0;k<MULT_R;k=k+1) begin:GEN_SAD
            assign out_sad[ (j*SAD_BITS)+(k*MULT_D*SAD_BITS) +: SAD_BITS ] = sad[ (k*SAD_BITS) +: SAD_BITS ];
        end

        dlsc_stereobm_pipe #(
            .MULT_R         ( MULT_R ),
            .SAD            ( SAD ),
            .DATA           ( DATA ),
            .SAD_BITS       ( SAD_BITS ),
            .PIPELINE_IN    ( PIPELINE_IN )
        ) dlsc_stereobm_pipe_inst (
            .clk            ( clk ),
            .rst            ( rst ),
            .in_right_valid ( in_right_valid ),
            .in_valid       ( in_valid ),
            .in_first       ( in_first ),
            .in_left        ( in_left ),
            .in_right       ( cascade_right[j] ),
            .cascade_right  ( cascade_right[j+1] ),
            .out_valid      ( out_valids[j] ),
            .out_sad        ( sad )
        );

    end
endgenerate


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"
task report;
begin
    GEN_PIPES[0].dlsc_stereobm_pipe_inst.report;
end
endtask
`include "dlsc_sim_bot.vh"
`endif

endmodule

