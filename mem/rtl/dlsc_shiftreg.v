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
// Infers LUT-based dynamic shift-register with synchronous write and
// asynchronous read.

module dlsc_shiftreg #(
    parameter DATA      = 32,
    parameter ADDR      = 4,
    parameter DEPTH     = (2**ADDR),
    parameter WARNINGS  = 1
) (
    input   wire                clk,            // writes synchronous to this clock
    input   wire                write_en,       // write enable
    input   wire    [DATA-1:0]  write_data,     // data written to address 0 on clock
    input   wire    [ADDR-1:0]  read_addr,      // read_address to asynchronously read from
    output  wire    [DATA-1:0]  read_data       // data read from read_addr
);

`include "dlsc_synthesis.vh"

`DLSC_SHREG reg [DATA-1:0] mem [DEPTH-1:0];

integer i;

assign read_data = mem[read_addr];

always @(posedge clk) begin
    if(write_en) begin
        for(i=DEPTH-1;i>=1;i=i-1) begin
            mem[i] <= mem[i-1];
        end
        mem[0] <= write_data;
    end
end

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"
generate
if(WARNINGS) begin:GEN_WARNINGS
    always @(posedge clk) begin
        if(read_addr >= DEPTH) begin
            `dlsc_warn("read_addr (0x%0x) exceeds shift register bounds (0x%0x)", read_addr, DEPTH);
        end
    end
end
endgenerate
`include "dlsc_sim_bot.vh"
`endif

endmodule

