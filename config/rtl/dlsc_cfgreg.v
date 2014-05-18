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
// Module for implementing semi-static configuration registers.
// Wrapper for cfgreg_slice; contains address-decoding logic.

module dlsc_cfgreg #(
    parameter INDEX     = 0,            // address of this register
    parameter DATA      = 1,            // width of register
    parameter ADDR      = 4,            // width of write address input
    parameter CFG_DATA  = DATA,         // width of write data input
    parameter WARNINGS  = 1             // enable warnings about lost MSbits
) (
    // system
    input   wire                    clk,

    // input from cfgreg_loader
    input   wire    [ADDR-1:0]      cfg_wr_addr,
    input   wire    [CFG_DATA-1:0]  cfg_wr_data,

    // output
    // may have multicycle timing constraint applied
    output  wire    [DATA-1:0]      out
);

`include "dlsc_util.vh"

`dlsc_static_assert_range( INDEX, 0, (2**ADDR)-2 )

// decode address

reg cfg_wr_en;
always @(posedge clk) begin
    /* verilator lint_off WIDTH */
    cfg_wr_en <= (cfg_wr_addr == INDEX);
    /* verilator lint_on WIDTH */
end

// implement register

dlsc_cfgreg_slice #(
    .DATA       ( DATA ),
    .IN_DATA    ( CFG_DATA ),
    .WARNINGS   ( WARNINGS )
) dlsc_cfgreg_slice (
    .clk        ( clk ),
    .clk_en     ( cfg_wr_en ),
    .rst        ( 1'b0 ),
    .in         ( cfg_wr_data ),
    .out        ( out )
);

endmodule

