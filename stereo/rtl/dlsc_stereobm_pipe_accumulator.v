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
// Implements the accumulator and delay-line needed to create a sliding SAD
// window. New values are added to the accumulator each valid cycle, and old
// values (now falling outside the window) are subtracted. Output is only
// produced once the accumulator has initially filled with an entire window.
//
// This module houses the common control logic, while
// dlsc_stereobm_pipe_accumulator_slice has the rest.

module dlsc_stereobm_pipe_accumulator #(
    parameter IN_BITS       = 12,
    parameter OUT_BITS      = 16,
    parameter SAD           = 9,
    parameter MULT_R        = 4,
    // derived parameters; don't touch
    parameter IN_BITS_R     = (IN_BITS*MULT_R),
    parameter OUT_BITS_R    = (OUT_BITS*MULT_R)
) (
    input   wire                    clk,
    input   wire                    rst,

    input   wire                    in_valid,
    input   wire                    in_first,
    input   wire [IN_BITS_R-1:0]    in_sad,

    output  reg                     out_valid,
    output  wire [OUT_BITS_R-1:0]   out_sad
);

`include "dlsc_clog2.vh"
localparam SAD_BITS = `dlsc_clog2(SAD);


// masking control logic
// shift-register output needs to be masked for SAD cycles
// output needs to be masked for SAD-1 cycles
// masking time is inclusive of in_first cycle

reg     [SAD_BITS-1:0]  cnt;
reg                     c1_en_sr;
reg                     c1_en_out;

always @(posedge clk) begin
    if(in_valid) begin
        if(in_first) begin
            cnt         <= 0;
            c1_en_sr    <= 1'b0;
            c1_en_out   <= 1'b0;
        end else if(!c1_en_sr) begin
            cnt         <= cnt + 1;
/* verilator lint_off WIDTH */
            if(cnt == (SAD-2)) c1_en_out <= 1'b1;
            if(cnt == (SAD-1)) c1_en_sr  <= 1'b1;
/* verilator lint_on WIDTH */
        end
    end
end


// delay in_first to c2_first
wire c2_first;
dlsc_pipedelay #(
    .DATA       ( 1 ),
    .DELAY      ( 2 )
) dlsc_pipedelay_inst_first (
    .clk        ( clk ),
    .in_data    ( in_first ),
    .out_data   ( c2_first )
);


reg c1_valid;
reg c2_out_valid;
reg c3_out_valid;

always @(posedge clk) begin
    if(rst) begin
        c1_valid        <= 1'b0;
        c2_out_valid    <= 1'b0;
        c3_out_valid    <= 1'b0;
        out_valid       <= 1'b0;
    end else begin
        c1_valid        <= in_valid;
        c2_out_valid    <= c1_valid && c1_en_out;
        c3_out_valid    <= c2_out_valid;
        out_valid       <= c3_out_valid;
    end
end


generate
    genvar j;
    for(j=0;j<MULT_R;j=j+1) begin:GEN_SLICES

        dlsc_stereobm_pipe_accumulator_slice #(
            .IN_BITS    ( IN_BITS ),
            .OUT_BITS   ( OUT_BITS ),
            .SAD        ( SAD )
        ) dlsc_stereobm_pipe_accumulator_slice_inst (
            .clk        ( clk ),
            .rst        ( rst ),
            .c0_sad     ( in_sad [ (j* IN_BITS) +:  IN_BITS ] ),
            .c4_out_sad ( out_sad[ (j*OUT_BITS) +: OUT_BITS ] ),
            .c1_valid   ( c1_valid ),
            .c1_en_sr   ( c1_en_sr ),
            .c2_first   ( c2_first )
        );

    end
endgenerate

//`ifdef DLSC_SIMULATION
//wire [IN_BITS-1:0] inputs [MULT_R-1:0];
//wire [OUT_BITS-1:0] outputs [MULT_R-1:0];
//
//generate
//    genvar g;
//    for(g=0;g<MULT_R;g=g+1) begin:GEN_DBG
//        assign inputs[g] = in_sad[(g*IN_BITS)+:IN_BITS];
//        assign outputs[g] = out_sad[(g*OUT_BITS)+:OUT_BITS];
//    end
//endgenerate
//`endif

endmodule

