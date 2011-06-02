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
// Reset synchronizer and fanout buffer. Incoming asynchronous reset forces
// register chain into reset state. Once reset is removed, chain clocks in the
// non-reset value. Metastability is possible on first flop in chain (if reset
// is removed near clock edge), so synchronizer flops are present.
//
// Based on Xilinx Language Templates "Asynchronous Input Synchronization".

module dlsc_rstsync #(
    parameter DEPTH = 4
) (
/* verilator lint_off SYNCASYNCNET */
    input       wire    rst_async,  // asynchronous reset input
    input       wire    clk,        // clock (which the reset will be synchronized to)
    output      wire    rst         // synchronous reset output
);

`include "dlsc_synthesis.vh"

// synchronizer
(* ASYNC_REG="TRUE", SHIFT_EXTRACT="NO", HBLKNM="sync_reg" *) reg [1:0] sreg = 2'b11;
always @(posedge clk or posedge rst_async) begin
    if(rst_async) begin
        sreg    <= 2'b11;
    end else begin
        sreg    <= { sreg[0], 1'b0 };
    end
end

// fanout control
`DLSC_FANOUT_REG(16) reg [DEPTH-1:0] rst_fanout;
always @(posedge clk or posedge rst_async) begin
    if(rst_async) begin
        rst_fanout <= {DEPTH{1'b1}};
    end else begin
        rst_fanout <= { rst_fanout[DEPTH-2:0], sreg[1] };
    end
end

assign rst = rst_fanout[DEPTH-1];

/* verilator lint_on SYNCASYNCNET */

endmodule

