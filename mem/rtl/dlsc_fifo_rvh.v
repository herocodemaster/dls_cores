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
// FIFO with ready/valid handshake interface on both input and output.

module dlsc_fifo_rvh (
    // system
    clk,
    rst,
    // input
    wr_ready,
    wr_valid,
    wr_data,
    wr_almost_full,
    // output
    rd_ready,
    rd_valid,
    rd_data,
    rd_almost_empty
);

`include "dlsc_clog2.vh"
`include "dlsc_synthesis.vh"

// ** Parameters **

// one of these must be set:
parameter DEPTH         = 0;                    // depth of FIFO (if unset, will default to 2**ADDR)
parameter ADDR          = `dlsc_clog2(DEPTH);   // address bits (if unset, will be set appropriately for DEPTH)
                                                // (width of count/free ports is ADDR+1)

localparam DEPTHI       = (DEPTH==0) ? (2**ADDR) : DEPTH;

parameter DATA          = 8;                    // width of data in FIFO
parameter ALMOST_FULL   = 0;                    // assert almost_full when <= ALMOST_FULL free spaces remain
parameter ALMOST_EMPTY  = 0;                    // assert almost_empty when <= ALMOST_EMPTY valid entries remain
parameter FAST_FLAGS    = 1;                    // disallow pessimistic flags
parameter BRAM          = ((DATA*DEPTHI)>=2048);// use block RAM (instead of distributed RAM)
parameter REGISTER      = 1;                    // register output


// ** Ports **

// system
input   wire                clk;
input   wire                rst;

// input
output  wire                wr_ready;
input   wire                wr_valid;
input   wire    [DATA-1:0]  wr_data;
output  wire                wr_almost_full;

// output
input   wire                rd_ready;
output  wire                rd_valid;
output  wire    [DATA-1:0]  rd_data;
output  wire                rd_almost_empty;


// ** Implementation **

wire            full;
assign          wr_ready        = !full;

wire            empty;
wire            pop;
wire [DATA-1:0] pop_data;

dlsc_fifo #(
    .DEPTH          ( DEPTH ),
    .ADDR           ( ADDR ),
    .DATA           ( DATA ),
    .ALMOST_FULL    ( ALMOST_FULL ),
    .ALMOST_EMPTY   ( ALMOST_EMPTY ),
    .COUNT          ( 0 ),
    .FREE           ( 0 ),
    .FAST_FLAGS     ( FAST_FLAGS ),
    .FULL_IN_RESET  ( 1 ),
    .BRAM           ( BRAM )
) dlsc_fifo_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( wr_ready && wr_valid ),
    .wr_data        ( wr_data ),
    .wr_full        ( full ),
    .wr_almost_full ( wr_almost_full ),
    .wr_free        (  ),
    .rd_pop         ( pop ),
    .rd_data        ( pop_data ),
    .rd_empty       ( empty ),
    .rd_almost_empty( rd_almost_empty ),
    .rd_count       (  )
);

generate
// no need to register for shallow (DEPTH<=2) FIFOs, since they're
// internally registered
if(REGISTER>0 && DEPTHI>2) begin:GEN_REG

    `DLSC_NO_SHREG reg [DATA-1:0] data;
    
    reg             valid;

    assign          rd_valid        = valid;
    assign          rd_data         = data;
    assign          pop             = !empty && (!valid || rd_ready);

    always @(posedge clk) begin
        if(rst) begin
            valid   <= 1'b0;
        end else begin
            if(rd_ready) valid <= 1'b0;
            if(pop)      valid <= 1'b1;
        end
    end

    always @(posedge clk) begin
        if(pop) begin
            data    <= pop_data;
        end
    end

end else begin:GEN_NOREG

    assign          rd_valid        = !empty;
    assign          rd_data         = pop_data;
    assign          pop             = !empty && rd_ready;

end
endgenerate

endmodule

