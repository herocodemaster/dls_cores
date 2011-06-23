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
// Frequency synthesizer. Generates non-integer divisions of input clock
// (e.g. for use as a UART baud rate generator)
// based on: http://excamera.com/sphinx/vhdl-clock.html

module dlsc_clocksynth #(
    parameter FREQ_IN  = 100000000,
    parameter FREQ_OUT = 115200
) (
    // input clock
    input   wire        clk,
    input   wire        rst,

    // enable for synthesized clock
    // (will always be enabled in reset, and on 1st cycle following reset)
    output  wire        clk_en_out
);

`include "dlsc_clog2.vh"

localparam BITS = `dlsc_clog2(FREQ_IN);

reg [BITS:0] cnt;

assign clk_en_out = !cnt[BITS];

/* verilator lint_off WIDTH */

always @(posedge clk) begin
    if(rst) begin
        cnt     <= 0;
    end else begin
        cnt     <= clk_en_out ? (cnt + FREQ_OUT - FREQ_IN) : (cnt + FREQ_OUT); 
    end
end

/* verilator lint_on WIDTH */

endmodule

