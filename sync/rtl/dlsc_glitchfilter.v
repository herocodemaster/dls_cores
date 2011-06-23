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
// Synchronizer and glitch-filter. Output only changes once DEPTH consecutive
// input samples agree on value.

module dlsc_glitchfilter #(
    parameter   DEPTH = 4,
    parameter   RESET = 1'b0
) (
    input   wire            clk,
    input   wire            clk_en,
    input   wire            rst,

    input   wire            in,

    output  reg             out
);

// synchronizer

wire in_synced;

dlsc_syncflop #(
    .DATA   ( 1 ),
    .RESET  ( RESET )
) dlsc_syncflop_inst (
    .rst    ( rst ),
    .in     ( in ),
    .clk    ( clk ),
    .out    ( in_synced )
);

// glitch filter

reg  [DEPTH-1:0] sr;
wire [DEPTH  :0] sr_next = {sr,in_synced};

always @(posedge clk) begin
    if(rst) begin
        sr      <= {DEPTH{RESET}};
        out     <= RESET;
    end else if(clk_en) begin
        sr      <= sr_next[DEPTH-1:0];

        // output only changes once all stages agree
        if( sr == {DEPTH{1'b0}} ) out <= 1'b0;
        if( sr == {DEPTH{1'b1}} ) out <= 1'b1;
    end
end

endmodule

