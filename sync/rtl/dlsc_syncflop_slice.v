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
// Multi-stage synchronizer flipflop for asynchronous domain crossing.

module dlsc_syncflop_slice (
    in,
    clk,
    rst,
    out
);

/* verilator lint_off SYNCASYNCNET */

`include "dlsc_synthesis.vh"

parameter       DEPTH = 2;          // >= 2; TODO: support higher depths
parameter       ASYNC = 0;          // asynchronous reset
parameter       RESET = 1'b0;       // reset value

input   in;
input   clk;
input   rst;
output  out;

wire    in;
wire    clk;
wire    rst;
wire    out;

`DLSC_SYNCFLOP reg dlsc_syncflop_src_reg;
`DLSC_SYNCFLOP reg dlsc_syncflop_dst_reg;

assign out = dlsc_syncflop_dst_reg;

generate
if(ASYNC==0) begin:GEN_SYNC

    always @(posedge clk) begin
        if(rst) begin
            dlsc_syncflop_src_reg <= RESET;
            dlsc_syncflop_dst_reg <= RESET;
        end else begin
            dlsc_syncflop_src_reg <= in;
            dlsc_syncflop_dst_reg <= dlsc_syncflop_src_reg;
        end
    end

end else begin:GEN_ASYNC

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            dlsc_syncflop_src_reg <= RESET;
            dlsc_syncflop_dst_reg <= RESET;
        end else begin
            dlsc_syncflop_src_reg <= in;
            dlsc_syncflop_dst_reg <= dlsc_syncflop_src_reg;
        end
    end

end
endgenerate

/* verilator lint_on SYNCASYNCNET */

endmodule

