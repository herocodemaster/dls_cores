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
// Synchronous FIFO using distributed or block RAM.

module dlsc_fifo_ram #(
    parameter DATA          = 8,    // width of data in FIFO
    parameter ADDR          = 4,    // depth of FIFO is 2**ADDR
    parameter ALMOST_FULL   = 0,    // assert almost_full when <= ALMOST_FULL free spaces remain (0 makes it equivalent to full)
    parameter ALMOST_EMPTY  = 0,    // assert almost_empty when <= ALMOST_EMPTY valid entries remain (0 makes it equivalent to empty)
    parameter FAST_FLAGS    = 0,    // disallow pessimistic flags
    parameter FULL_IN_RESET = 0,    // force full flags to be set when in reset
    parameter BRAM          = (DATA*(2**ADDR)>=4096) // use block RAM (instead of distributed RAM)
) (
    // system
    input   wire                clk,
    input   wire                rst,
    
    // input
    input   wire                wr_push,
    input   wire    [DATA-1:0]  wr_data,
    output  wire                wr_full,
    output  wire                wr_almost_full,
    output  wire    [ADDR:0]    wr_free,

    // output
    input   wire                rd_pop,
    output  wire    [DATA-1:0]  rd_data,
    output  wire                rd_empty,
    output  wire                rd_almost_empty,
    output  wire    [ADDR:0]    rd_count
);

`include "dlsc_synthesis.vh"

localparam DEPTH    = (2**ADDR);


// ** storage memory **

reg  [ADDR-1:0] wr_addr;
reg  [ADDR-1:0] rd_addr;
wire [ADDR-1:0] rd_addr_next;
wire            rd_en;

generate
if(!BRAM || FAST_FLAGS) begin:GEN_LUTRAM

    if(FAST_FLAGS) begin:GEN_LUTRAM_ASYNC
        
        `DLSC_LUTRAM reg [DATA-1:0] mem[DEPTH-1:0];

        assign          rd_data         = mem[rd_addr];

        always @(posedge clk) begin
            if(wr_push) begin
                mem[wr_addr]    <= wr_data;
            end
        end

    end else begin:GEN_LUTRAM_SYNC

        `DLSC_LUTRAM reg [DATA-1:0] mem[DEPTH-1:0];

        reg  [DATA-1:0] mem_rd_data;
        assign          rd_data         = mem_rd_data;

        always @(posedge clk) begin
            if(wr_push) begin
                mem[wr_addr]    <= wr_data;
            end
        end
        always @(posedge clk) begin
            if(rd_en) begin
                mem_rd_data     <= mem[rd_addr_next];
            end
        end

    end

end else begin:GEN_BRAM

    dlsc_ram_dp #(
        .DATA           ( DATA ),
        .ADDR           ( ADDR ),
        .PIPELINE_WR    ( 0 ),
        .PIPELINE_RD    ( 1 ),
        .WARNINGS       ( 0 )
    ) dlsc_ram_dp_inst (
        .write_clk      ( clk ),
        .write_en       ( wr_push ),
        .write_addr     ( wr_addr ),
        .write_data     ( wr_data ),
        .read_clk       ( clk ),
        .read_en        ( rd_en ),
        .read_addr      ( rd_addr_next ),
        .read_data      ( rd_data )
    );

end
endgenerate


// ** address generation **

reg  [ADDR-1:0] rd_addr_p1;

assign          rd_addr_next    = rd_pop ? rd_addr_p1 : rd_addr;

always @(posedge clk) begin
    if(rst) begin
        wr_addr     <= 0;
        rd_addr     <= 0;
        rd_addr_p1  <= 1;
    end else begin
        if(wr_push) begin
            wr_addr     <= wr_addr + 1;
        end
        if(rd_pop) begin
            rd_addr     <= rd_addr_p1;
            rd_addr_p1  <= rd_addr_p1 + 1;
        end
    end
end


// ** flags **

dlsc_fifo_counter #(
    .ADDR           ( ADDR ),
    .ALMOST_FULL    ( ALMOST_FULL ),
    .ALMOST_EMPTY   ( ALMOST_EMPTY ),
    .FAST_FLAGS     ( FAST_FLAGS ),
    .FULL_IN_RESET  ( FULL_IN_RESET )
) dlsc_fifo_counter_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( wr_push ),
    .wr_full        ( wr_full ),
    .wr_almost_full ( wr_almost_full ),
    .wr_free        ( wr_free ),
    .rd_pop         ( rd_pop ),
    .rd_empty       ( rd_empty ),
    .rd_almost_empty( rd_almost_empty ),
    .rd_count       ( rd_count )
);

// read on pop, or after first entry is written
assign          rd_en           = rd_pop || (rd_empty && rd_count == 1);

endmodule

