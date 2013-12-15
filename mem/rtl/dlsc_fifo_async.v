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
// Generic asynchronous FIFO wrapper. Selects best FIFO based on parameters.

module dlsc_fifo_async #(
    parameter WR_CYCLES     = 1,    // max input rate
    parameter RD_CYCLES     = 1,    // max output rate
    parameter WR_PIPELINE   = 0,    // delay from wr_push to wr_data being valid (0 or 1)
    parameter RD_PIPELINE   = 0,    // delay from rd_pop to rd_data being valid (0 or 1)
    parameter DATA          = 8,    // width of data in FIFO
    parameter ADDR          = 4,    // depth of FIFO is 2**ADDR; width of free/count ports is ADDR+1
    parameter ALMOST_FULL   = 0,    // assert almost_full when <= ALMOST_FULL free spaces remain (0 makes it equivalent to full)
    parameter ALMOST_EMPTY  = 0,    // assert almost_empty when <= ALMOST_EMPTY valid entries remain (0 makes it equivalent to empty)
    parameter FREE          = 0,    // enable wr_free port
    parameter COUNT         = 0,    // enable rd_count port
    // use block RAMs (instead of LUTs)
    parameter BRAM          = (ADDR > 6) && (((2**ADDR)*DATA) > 1024)
) (
    // ** write domain **

    input   wire                wr_clk,
    input   wire                wr_rst,

    output  wire                wr_full,
    input   wire                wr_push,
    input   wire    [DATA-1:0]  wr_data,

    output  wire                wr_almost_full,
    output  wire    [ADDR  :0]  wr_free,
    
    // ** read domain **

    input   wire                rd_clk,
    input   wire                rd_rst,

    input   wire                rd_pop,
    output  wire                rd_empty,
    output  wire    [DATA-1:0]  rd_data,

    output  wire                rd_almost_empty,
    output  wire    [ADDR  :0]  rd_count
);

dlsc_fifo_async_full #(
    .WR_CYCLES      ( WR_CYCLES ),
    .RD_CYCLES      ( RD_CYCLES ),
    .WR_PIPELINE    ( WR_PIPELINE ),
    .RD_PIPELINE    ( RD_PIPELINE ),
    .DATA           ( DATA ),
    .ADDR           ( ADDR ),
    .ALMOST_FULL    ( ALMOST_FULL ),
    .ALMOST_EMPTY   ( ALMOST_EMPTY ),
    .FREE           ( FREE ),
    .COUNT          ( COUNT ),
    .BRAM           ( BRAM )
) dlsc_fifo_async_full (
    .wr_clk         ( wr_clk ),
    .wr_rst         ( wr_rst ),
    .wr_full        ( wr_full ),
    .wr_push        ( wr_push ),
    .wr_data        ( wr_data ),
    .wr_almost_full ( wr_almost_full ),
    .wr_free        ( wr_free ),
    .rd_clk         ( rd_clk ),
    .rd_rst         ( rd_rst ),
    .rd_pop         ( rd_pop ),
    .rd_empty       ( rd_empty ),
    .rd_data        ( rd_data ),
    .rd_almost_empty ( rd_almost_empty ),
    .rd_count       ( rd_count )
);

// ** simulation checks **

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @(posedge wr_clk) begin
    if(!wr_rst && wr_push && wr_full) begin
        `dlsc_error("overflow");
    end
end

always @(posedge rd_clk) begin
    if(!rd_rst && rd_pop && rd_empty) begin
        `dlsc_error("underflow");
    end
end

`include "dlsc_sim_bot.vh"
`endif

endmodule

