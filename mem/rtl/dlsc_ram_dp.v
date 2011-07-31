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
// High-performance simple-dual-port RAM with independent clocks.
// Optional pipelining may be inserted on read and/or write paths to improve
// performance; block will use pipeline cycles to control fanout for large RAMs.

module dlsc_ram_dp #(
    parameter   DATA        = 32,
    parameter   ADDR        = 9,
    parameter   DEPTH       = (2**ADDR),
    parameter   PIPELINE_WR = 0,                // 0 or more
    parameter   PIPELINE_WR_DATA = PIPELINE_WR, // 0 or more
    parameter   PIPELINE_RD = 1,                // 1 or more (minimum read latency of 1 cycle)
    parameter   WARNINGS    = 1
) (
    // write port
    input   wire                write_clk,
    input   wire                write_en,
    input   wire    [ADDR-1:0]  write_addr,
    input   wire    [DATA-1:0]  write_data,
    
    // read port
    input   wire                read_clk,
    input   wire                read_en,
    input   wire    [ADDR-1:0]  read_addr,
    output  wire    [DATA-1:0]  read_data
);

`include "dlsc_synthesis.vh"

// ** shared delays **

wire            c0_read_en;
wire [ADDR-1:0] c0_read_addr;
wire            c0_write_en;
wire [ADDR-1:0] c0_write_addr;
wire [DATA-1:0] c0_write_data;

dlsc_pipedelay #(
    .DATA       ( ADDR + 1 ),
    .DELAY      ( (PIPELINE_RD>3) ? (PIPELINE_RD-3) : 0 )
) dlsc_pipedelay_inst_rdaddr (
    .clk        ( read_clk ),
    .in_data    ( {    read_en,    read_addr } ),
    .out_data   ( { c0_read_en, c0_read_addr } )
);

dlsc_pipedelay #(
    .DATA       ( ADDR + 1 ),
    .DELAY      ( (PIPELINE_WR>1)?(PIPELINE_WR-1):0 )
) dlsc_pipedelay_inst_wraddr (
    .clk        ( write_clk ),
    .in_data    ( {    write_en,    write_addr } ),
    .out_data   ( { c0_write_en, c0_write_addr } )
);

dlsc_pipedelay #(
    .DATA       ( DATA ),
    .DELAY      ( (PIPELINE_WR_DATA>1)?(PIPELINE_WR_DATA-1):0 )
) dlsc_pipedelay_inst_wrdata (
    .clk        ( write_clk ),
    .in_data    (    write_data ),
    .out_data   ( c0_write_data )
);

wire            c1_read_en;
wire [ADDR-1:0] c1_read_addr;
wire            c1_write_en;
wire [ADDR-1:0] c1_write_addr;
wire [DATA-1:0] c1_write_data;

generate

    if(PIPELINE_RD > 2) begin:GEN_RD_PIPE

        `DLSC_FANOUT_REG reg            c1_read_en_r;
        `DLSC_FANOUT_REG reg [ADDR-1:0] c1_read_addr_r;

        always @(posedge read_clk) begin
            c1_read_en_r    <= c0_read_en;
            c1_read_addr_r  <= c0_read_addr;
        end

        assign c1_read_en       = c1_read_en_r;
        assign c1_read_addr     = c1_read_addr_r;

    end else begin:GEN_RD_NOPIPE
        assign c1_read_en       = c0_read_en;
        assign c1_read_addr     = c0_read_addr;
    end

    if(PIPELINE_WR > 0) begin:GEN_WR_PIPE

        `DLSC_FANOUT_REG reg            c1_write_en_r;
        `DLSC_FANOUT_REG reg [ADDR-1:0] c1_write_addr_r;

        always @(posedge write_clk) begin
            c1_write_en_r   <= c0_write_en;
            c1_write_addr_r <= c0_write_addr;
        end

        assign c1_write_en      = c1_write_en_r;
        assign c1_write_addr    = c1_write_addr_r;

    end else begin:GEN_WR_NOPIPE
        assign c1_write_en      = c0_write_en;
        assign c1_write_addr    = c0_write_addr;
    end

    if(PIPELINE_WR_DATA > 0) begin:GEN_WRDATA_PIPE

        `DLSC_FANOUT_REG reg [DATA-1:0] c1_write_data_r;

        always @(posedge write_clk) begin
            c1_write_data_r <= c0_write_data;
        end

        assign c1_write_data    = c1_write_data_r;

    end else begin:GEN_WRDATA_NOPIPE
        assign c1_write_data    = c0_write_data;
    end

endgenerate

dlsc_ram_dp_slice #(
    .DATA           ( DATA ),
    .ADDR           ( ADDR ),
    .DEPTH          ( DEPTH ),
    .PIPELINE       ( (PIPELINE_RD>1) ? 1 : 0 ),
    .WARNINGS       ( WARNINGS )
) dlsc_ram_dp_slice_inst (
    .write_clk      ( write_clk ),
    .write_en       ( c1_write_en ),
    .write_addr     ( c1_write_addr ),
    .write_data     ( c1_write_data ),
    .read_clk       ( read_clk ),
    .read_en        ( c1_read_en ),
    .read_addr      ( c1_read_addr ),
    .read_data      ( read_data )
);

endmodule

