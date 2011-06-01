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
// This is a 'slice' that handles 1 row (out of MULT_R rows).

module dlsc_stereobm_pipe_accumulator_slice #(
    parameter IN_BITS       = 12,
    parameter OUT_BITS      = 16,
    parameter SAD           = 9
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // in
    input   wire [IN_BITS-1:0]      c0_sad,     // column SAD

    // out
    output  reg  [OUT_BITS-1:0]     c4_out_sad, // accumulated window SAD
    
    // control
    input   wire                    c1_valid,
    input   wire                    c1_en_sr,   // unmask shift-register output
    input   wire                    c2_first    // mask accumulator feedback
);

`include "dlsc_synthesis.vh"
`include "dlsc_clog2.vh"

localparam PAD = OUT_BITS - IN_BITS - 1;

`DLSC_KEEP_REG reg c2_valid;    // enable shift-register
`DLSC_KEEP_REG reg c3_valid;    // enable accumulator

always @(posedge clk) begin
    if(rst) begin
        c2_valid    <= 1'b0;
        c3_valid    <= 1'b0;
    end else begin
        c2_valid    <= c1_valid;
        c3_valid    <= c2_valid;
    end
end


// delay c0_sad to c2_sad
wire [IN_BITS-1:0] c2_sad;

dlsc_pipedelay #(
    .DATA       ( IN_BITS ),
    .DELAY      ( 2 )
) dlsc_pipedelay_inst_sad (
    .clk        ( clk ),
    .in_data    ( c0_sad ),
    .out_data   ( c2_sad )
);


// delay-line
wire [IN_BITS-1:0] c2_sad_d;
dlsc_pipedelay_clken #(
    .DATA   ( IN_BITS ),
    .DELAY  ( SAD )
) dlsc_pipedelay_clken_inst (
    .clk        ( clk ),
    .clk_en     ( c2_valid ),
    .in_data    ( c2_sad ),
    .out_data   ( c2_sad_d )
);


`DLSC_KEEP_REG reg c2_en_sr; // unmask shift-register output

always @(posedge clk) begin
    c2_en_sr    <= c1_en_sr;
end

reg [IN_BITS:0]     c3_sad;         // 1 extra bit for possible negative value

// subtract delayed SAD value
always @(posedge clk) begin
    c3_sad      <= {1'b0,c2_sad} - ( {1'b0,c2_sad_d} & {(IN_BITS+1){c2_en_sr}} );
end


`DLSC_KEEP_REG reg c3_first; // mask accumulator feedback

always @(posedge clk) begin
    c3_first    <= c2_first;
end

// accumulate SAD window
always @(posedge clk) begin
    if(c3_valid) begin
        // qualified, since we only want to accumulate valid values
        c4_out_sad  <= {{PAD{c3_sad[IN_BITS]}},c3_sad} + ( c4_out_sad & {OUT_BITS{!c3_first}} );
    end
end

endmodule

