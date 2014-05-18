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
// Configurable ROM. Can be reconfigured prior to use.

module dlsc_cfgrom #(
    parameter DATA          = 4,            // bits for data (output)
    parameter ADDR          = 4,            // bits for address (input)
    parameter DEPTH         = (2**ADDR),    // entries in memory
    parameter RESET         = 0,            // output register reset value
    parameter PIPELINE      = 1             // delay from in_ to out_; must be 1 for now (TODO)
) (
    // system
    input   wire                        clk,

    // config
    // memory must be populated by writing sequentially from back to front
    input   wire                        cfg_en,         // assert for entire duration of config operation
    input   wire                        cfg_wr_en,
    input   wire    [ADDR-1:0]          cfg_wr_addr,
    input   wire    [DATA-1:0]          cfg_wr_data,

    // input
    input   wire                        in_rst,         // reset for output register (can be used for clamping)
    input   wire    [ADDR-1:0]          in_addr,

    // output
    output  wire    [DATA-1:0]          out_data
);

`include "dlsc_synthesis.vh"

// just a shift register
// TODO: this doesn't scale well to large memory sizes (> 16-32 deep); need to add support for other memory types

wire [DATA-1:0] c0_data;

dlsc_shiftreg #(
    .DATA       ( DATA ),
    .ADDR       ( ADDR ),
    .DEPTH      ( DEPTH )
) dlsc_shiftreg (
    .clk        ( clk ),
    .write_en   ( cfg_wr_en ),
    .write_data ( cfg_wr_data ),
    .read_addr  ( in_addr ),
    .read_data  ( c0_data )
);

// register output

`DLSC_PIPE_REG reg [DATA-1:0] out_data_r;
assign out_data = out_data_r;

always @(posedge clk) begin
    if(in_rst) begin
        out_data_r <= RESET;
    end else begin
        out_data_r <= c0_data;
    end
end

endmodule

