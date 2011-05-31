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
// Infers a simple-dual-port (1 write port, 1 read port) block RAM with
// independent clocks. Will generate warnings on read/write collisions (which
// typically yield indeterminate behavior in real hardware).
// Reads take 1 or 2 cycles (depending on if PIPELINE is set).

module dlsc_ram_dp_slice #(
    parameter   DATA        = 72,
    parameter   ADDR        = 9,
    parameter   DEPTH       = (2**ADDR),
    parameter   PIPELINE    = 0,    // enable additional pipeline register on output
    parameter   WARNINGS    = 1
) (
    // write port
    input   wire                write_clk,
    input   wire                write_en,
    input   wire    [ADDR-1:0]  write_addr,
    input   wire    [DATA-1:0]  write_data,
    
    // read port
    input   wire                read_en,
    input   wire                read_clk,
    input   wire    [ADDR-1:0]  read_addr,
    output  wire    [DATA-1:0]  read_data
);

`include "dlsc_synthesis.vh"

`DLSC_BRAM reg [DATA-1:0] mem [DEPTH-1:0];

always @(posedge write_clk) begin
    if(write_en) begin
        mem[write_addr] <= write_data;
    end
end

reg [DATA-1:0] read_data_r0;
reg [DATA-1:0] read_data_r1;

always @(posedge read_clk) begin
    if(read_en) begin
        read_data_r0    <= mem[read_addr];
    end
    read_data_r1    <= read_data_r0;

`ifdef SIMULATION
/* verilator coverage_off */
    if(write_en && read_en && read_addr == write_addr) begin
        read_data_r0    <= {DATA{1'bx}};
`ifndef DLSC_SIMULATION
        if(WARNINGS>0) begin
            $display("%t: [%m] *** WARNING *** read/write overlap (0x%0x)", $time, read_addr);
        end
`endif
    end
/* verilator coverage_on */
`endif

end

generate
if(PIPELINE==0) begin:GEN_NOPIPE

    // 1-cycle latency
    assign read_data = read_data_r0;

end else begin:GEN_PIPE

    // 2-cycle latency
    assign read_data = read_data_r1;

end
endgenerate


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"
always @(posedge read_clk) begin
    if(read_en && read_addr >= DEPTH) begin
        `dlsc_error("read_addr (0x%0x) exceeds memory bounds (0x%0x)", read_addr, DEPTH);
    end
end
always @(posedge write_clk) begin
    if(write_en && write_addr >= DEPTH) begin
        `dlsc_error("write_addr (0x%0x) exceeds memory bounds (0x%0x)", write_addr, DEPTH);
    end
end
if(WARNINGS>0) begin:GEN_WARNINGS
    always @* begin
        if(write_en && read_en && read_addr == write_addr) begin
            `dlsc_warn("read/write overlap (0x%0x)", read_addr);
        end
    end
end
`include "dlsc_sim_bot.vh"
`endif

endmodule

