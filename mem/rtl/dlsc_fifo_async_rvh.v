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
// Async FIFO with ready/valid handshake interface on both input and output.

module dlsc_fifo_async_rvh #(
    parameter WR_CYCLES     = 1,    // max input rate
    parameter RD_CYCLES     = 1,    // max output rate
    parameter DATA          = 8,    // width of data in FIFO
    parameter ADDR          = 4,    // depth of FIFO is 2**ADDR
    // use block RAMs (instead of LUTs)
    parameter BRAM          = (ADDR > 6) && (((2**ADDR)*DATA) > 1024)
) (
    // ** write domain **

    input   wire                wr_clk,
    input   wire                wr_rst,

    output  wire                wr_ready,
    input   wire                wr_valid,
    input   wire    [DATA-1:0]  wr_data,
    
    // ** read domain **

    input   wire                rd_clk,
    input   wire                rd_rst,

    input   wire                rd_ready,
    output  wire                rd_valid,
    output  wire    [DATA-1:0]  rd_data
);

`include "dlsc_synthesis.vh"

generate
if(ADDR <= 1) begin:GEN_DOMAINCROSS_RVH

    dlsc_domaincross_rvh #(
        .BYPASS         ( 0 ),
        .DATA           ( DATA )
    ) dlsc_domaincross_rvh (
        .in_clk         ( wr_clk ),
        .in_rst         ( wr_rst ),
        .in_ready       ( wr_ready ),
        .in_valid       ( wr_valid ),
        .in_data        ( wr_data ),
        .out_clk        ( rd_clk ),
        .out_rst        ( rd_rst ),
        .out_ready      ( rd_ready ),
        .out_valid      ( rd_valid ),
        .out_data       ( rd_data )
    );

end else begin:GEN_FIFO_ASYNC

    wire            wr_full;
    wire            wr_push;

    assign          wr_ready    = !wr_full;
    assign          wr_push     = !wr_full && wr_valid;

    wire            rd_empty;
    wire            rd_pop;
    wire [DATA-1:0] rd_pop_data;

    dlsc_fifo_async #(
        .WR_CYCLES      ( WR_CYCLES ),
        .RD_CYCLES      ( RD_CYCLES ),
        .WR_PIPELINE    ( 0 ),
        .RD_PIPELINE    ( 0 ),
        .DATA           ( DATA ),
        .ADDR           ( ADDR ),
        .ALMOST_FULL    ( 0 ),
        .ALMOST_EMPTY   ( 0 ),
        .FREE           ( 0 ),
        .COUNT          ( 0 ),
        .BRAM           ( BRAM )
    ) dlsc_fifo_async (
        .wr_clk         ( wr_clk ),
        .wr_rst         ( wr_rst ),
        .wr_push        ( wr_push ),
        .wr_data        ( wr_data ),
        .wr_full        ( wr_full ),
        .wr_almost_full (  ),
        .wr_free        (  ),
        .rd_clk         ( rd_clk ),
        .rd_rst         ( rd_rst ),
        .rd_pop         ( rd_pop ),
        .rd_data        ( rd_pop_data ),
        .rd_empty       ( rd_empty ),
        .rd_almost_empty(  ),
        .rd_count       (  )
    );

    assign rd_pop = !rd_empty && (!rd_valid || (rd_ready && RD_CYCLES <= 1));

    `DLSC_PIPE_REG reg            rd_valid_r;
    `DLSC_PIPE_REG reg [DATA-1:0] rd_data_r;

    assign rd_valid = rd_valid_r;
    assign rd_data  = rd_data_r;

    always @(posedge rd_clk) begin
        if(rd_rst) begin
            rd_valid_r <= 1'b0;
        end else begin
            if(rd_ready) rd_valid_r <= 1'b0;
            if(rd_pop)   rd_valid_r <= 1'b1;
        end
    end

    always @(posedge rd_clk) begin
        if(rd_pop) begin
            rd_data_r <= rd_pop_data;
        end
    end

end
endgenerate

endmodule

