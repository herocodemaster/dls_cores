// 
// Copyright (c) 2013, Daniel Strother < http://danstrother.com/ >
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
// Config loading control logic for cfgreg.

module dlsc_cfgreg_loader #(
    parameter ADDR          = 4,                // bits for cfgreg select address; must be enough for DEPTH+1 (all 1's is invalid)
    parameter DEPTH         = (2**ADDR)-1,      // number of cfgregs to load; this is also the length of the configuration stream
    parameter CFG_DATA      = 8                 // width of configuration stream
) (
    // system
    input   wire                        clk,
    input   wire                        rst,

    // status
    output  reg                         done,

    // config stream input
    output  reg                         in_ready,
    input   wire                        in_valid,
    input   wire    [CFG_DATA-1:0]      in_data,

    // config stream output
    input   wire                        out_ready,
    output  reg                         out_valid,
    output  reg     [CFG_DATA-1:0]      out_data,

    // config output to cfgreg
    // address is valid 1 cycle before data (to allow for pipelined decoding)
    // address is all 1's when no write is to be performed
    output  wire    [ADDR-1:0]          cfg_wr_addr,
    output  wire    [CFG_DATA-1:0]      cfg_wr_data
);

`include "dlsc_util.vh"
`include "dlsc_synthesis.vh"

`dlsc_static_assert_range( DEPTH, 1, (2**ADDR)-1 )

wire c0_en   = (in_ready && in_valid);
`DLSC_PIPE_REG reg c1_en;

always @(posedge clk) begin
    c1_en <= c0_en;
end

`DLSC_PIPE_REG reg [ADDR-1:0] addr;
`DLSC_PIPE_REG reg addr_last;

/* verilator lint_off WIDTH */
always @(posedge clk) begin
    if(rst) begin
        addr        <= 0;
        addr_last   <= (DEPTH<=1);
    end else if(c1_en) begin
        if(!addr_last) begin
            addr        <= addr + 1;
            addr_last   <= (DEPTH<=2) || (addr == (DEPTH-2));
        end else begin
            addr        <= {ADDR{1'b1}};
            addr_last   <= 1'b1;
        end
    end
end
/* verilator lint_on WIDTH */

always @(posedge clk) begin 
    if(rst) begin
        done        <= 1'b0;
    end else begin
        // done asserts coincident with final write; probably not a big deal
        done        <= done || (c0_en && addr_last);
    end
end

always @(posedge clk) begin
    if(rst) begin
        in_ready    <= 1'b0;
        out_valid   <= 1'b0;
    end else begin
        in_ready    <= !c0_en && !out_valid;
        out_valid   <= (c0_en && done) || (out_valid && !out_ready);
    end
end

always @(posedge clk) begin
    if(c0_en) begin
        out_data    <= in_data;
    end
end

assign cfg_wr_addr  = addr;
assign cfg_wr_data  = out_data;

endmodule

