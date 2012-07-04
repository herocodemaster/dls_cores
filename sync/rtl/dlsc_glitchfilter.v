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
// Synchronizer and glitch-filter. Output only changes once input is stable
// for DEPTH consecutive enabled clock cycles.

module dlsc_glitchfilter #(
    parameter   SYNC  = 1,      // include syncflop
    parameter   DEPTH = 4,
    parameter   RESET = 1'b0
) (
    input   wire            clk,
    input   wire            clk_en,
    input   wire            rst,

    input   wire            in,

    output  reg             out
);

`include "dlsc_clog2.vh"

localparam CNTB = `dlsc_clog2(DEPTH);

// synchronizer

wire in_synced;

generate
if(SYNC>0) begin:GEN_SYNC
    dlsc_syncflop #(
        .DATA   ( 1 ),
        .RESET  ( RESET )
    ) dlsc_syncflop_inst (
        .rst    ( rst ),
        .in     ( in ),
        .clk    ( clk ),
        .out    ( in_synced )
    );
end else begin:GEN_NOSYNC
    assign in_synced = in;
end
endgenerate

// glitch filter

reg             in_prev     = RESET;
wire            in_change   = (in_prev != in_synced);

reg             in_stable_r = 1'b0;
wire            in_stable   = in_stable_r && !in_change;

reg  [CNTB-1:0] cnt         = 0;

always @(posedge clk) begin
    if(rst || in_change) begin
        cnt         <= 0;
        in_stable_r <= 1'b0;
    end else if(clk_en && !in_stable_r) begin
        cnt         <= cnt + 1;
        /* verilator lint_off WIDTH */
        in_stable_r <= (cnt == (DEPTH-1));
        /* veirlator lint_on WIDTH */
    end
end

always @(posedge clk) begin
    if(rst) begin
        in_prev     <= RESET;
        out         <= RESET;
    end else begin
        in_prev     <= in_synced;
        if(in_stable) begin
            out         <= in_prev;
        end
    end
end

endmodule

