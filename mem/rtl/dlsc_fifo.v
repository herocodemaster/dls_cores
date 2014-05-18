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
// Generic synchronous FIFO wrapper. Selects best (shiftreg or RAM) FIFO based
// on parameters.

module dlsc_fifo (
    // system
    clk,
    rst,
    // input
    wr_push,
    wr_data,
    wr_full,
    wr_almost_full,
    wr_free,
    // output
    rd_pop,
    rd_data,
    rd_empty,
    rd_almost_empty,
    rd_count
);

`include "dlsc_clog2.vh"

// ** Parameters **

// one of these must be set:
parameter DEPTH         = 0;                    // depth of FIFO (if unset, will default to 2**ADDR)
parameter ADDR          = `dlsc_clog2(DEPTH);   // address bits (if unset, will be set appropriately for DEPTH)
                                                // (width of count/free ports is ADDR+1)

localparam DEPTHI       = (DEPTH==0) ? (2**ADDR) : DEPTH;

parameter DATA          = 8;                    // width of data in FIFO
parameter ALMOST_FULL   = 0;                    // assert almost_full when <= ALMOST_FULL free spaces remain
parameter ALMOST_EMPTY  = 0;                    // assert almost_empty when <= ALMOST_EMPTY valid entries remain
parameter COUNT         = 0;                    // enable rd_count port
parameter FREE          = 0;                    // enable wr_free port
parameter FAST_FLAGS    = 0;                    // disallow pessimistic flags
parameter FULL_IN_RESET = 0;                    // force full flags to be set when in reset
parameter BRAM          = ((DATA*DEPTHI)>=2048);// use block RAM (instead of distributed RAM)


// ** Ports **

// system
input   wire                clk;
input   wire                rst;

// input
input   wire                wr_push;
input   wire    [DATA-1:0]  wr_data;
output  wire                wr_full;
output  wire                wr_almost_full;
output  wire    [ADDR:0]    wr_free;

// output
input   wire                rd_pop;
output  wire    [DATA-1:0]  rd_data;
output  wire                rd_empty;
output  wire                rd_almost_empty;
output  wire    [ADDR:0]    rd_count;


// ** Implementation **

localparam  USE_SHIFTREG    = ( (DEPTHI <= 16) || 
                                (DEPTHI <= 32 && DATA <= 12) || 
                                (DEPTHI <= 64 && DATA <= 4) ||
                                (DEPTHI != (2**ADDR)) ) && !(COUNT || FREE);

generate
if(DEPTHI==1) begin:GEN_FIFO_ONE
    
    dlsc_fifo_one #(
        .DATA           ( DATA ),
        .ALMOST_FULL    ( ALMOST_FULL ),
        .ALMOST_EMPTY   ( ALMOST_EMPTY ),
//      .FAST_FLAGS     ( FAST_FLAGS ),     // fifo_one always has FAST_FLAGS
        .FULL_IN_RESET  ( FULL_IN_RESET )
    ) dlsc_fifo_one_inst (
        .clk            ( clk ),
        .rst            ( rst ),
        .wr_push        ( wr_push ),
        .wr_data        ( wr_data ),
        .wr_full        ( wr_full ),
        .wr_almost_full ( wr_almost_full ),
        .wr_free        ( wr_free ),
        .rd_pop         ( rd_pop ),
        .rd_data        ( rd_data ),
        .rd_empty       ( rd_empty ),
        .rd_almost_empty( rd_almost_empty ),
        .rd_count       ( rd_count )
    );

end else if(DEPTHI==2) begin:GEN_FIFO_TWO
    
    dlsc_fifo_two #(
        .DATA           ( DATA ),
        .ALMOST_FULL    ( ALMOST_FULL ),
        .ALMOST_EMPTY   ( ALMOST_EMPTY ),
//      .FAST_FLAGS     ( FAST_FLAGS ),     // fifo_two always has FAST_FLAGS
        .FULL_IN_RESET  ( FULL_IN_RESET )
    ) dlsc_fifo_two_inst (
        .clk            ( clk ),
        .rst            ( rst ),
        .wr_push        ( wr_push ),
        .wr_data        ( wr_data ),
        .wr_full        ( wr_full ),
        .wr_almost_full ( wr_almost_full ),
        .wr_free        ( wr_free ),
        .rd_pop         ( rd_pop ),
        .rd_data        ( rd_data ),
        .rd_empty       ( rd_empty ),
        .rd_almost_empty( rd_almost_empty ),
        .rd_count       ( rd_count )
    );

end else if(USE_SHIFTREG) begin:GEN_FIFO_SHIFTREG

    dlsc_fifo_shiftreg #(
        .DATA           ( DATA ),
        .DEPTH          ( DEPTHI ),
        .ALMOST_FULL    ( ALMOST_FULL ),
        .ALMOST_EMPTY   ( ALMOST_EMPTY ),
//      .FAST_FLAGS     ( FAST_FLAGS ),     // fifo_shiftreg always has FAST_FLAGS
        .FULL_IN_RESET  ( FULL_IN_RESET )
    ) dlsc_fifo_shiftreg_inst (
        .clk            ( clk ),
        .rst            ( rst ),
        .wr_push        ( wr_push ),
        .wr_data        ( wr_data ),
        .wr_full        ( wr_full ),
        .wr_almost_full ( wr_almost_full ),
        .rd_pop         ( rd_pop ),
        .rd_data        ( rd_data ),
        .rd_empty       ( rd_empty ),
        .rd_almost_empty( rd_almost_empty )
    );
    
    // TODO: wr_free, rd_count

    assign wr_free  = {(ADDR+1){1'bx}};
    assign rd_count = {(ADDR+1){1'bx}};

end else begin:GEN_FIFO_RAM

    dlsc_fifo_ram #(
        .DATA           ( DATA ),
        .ADDR           ( ADDR ),
        .ALMOST_FULL    ( ALMOST_FULL ),
        .ALMOST_EMPTY   ( ALMOST_EMPTY ),
        .COUNT          ( COUNT ),
        .FREE           ( FREE ),
        .FAST_FLAGS     ( FAST_FLAGS ),
        .FULL_IN_RESET  ( FULL_IN_RESET ),
        .BRAM           ( BRAM )
    ) dlsc_fifo_ram_inst (
        .clk            ( clk ),
        .rst            ( rst ),
        .wr_push        ( wr_push ),
        .wr_data        ( wr_data ),
        .wr_full        ( wr_full ),
        .wr_almost_full ( wr_almost_full ),
        .wr_free        ( wr_free ),
        .rd_pop         ( rd_pop ),
        .rd_data        ( rd_data ),
        .rd_empty       ( rd_empty ),
        .rd_almost_empty( rd_almost_empty ),
        .rd_count       ( rd_count )
    );

end
endgenerate


// ** simulation checks **

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @(posedge clk) begin
    if( wr_push && !rd_pop && wr_full ) begin
        `dlsc_error("overflow");
    end
    if(             rd_pop && rd_empty) begin
        `dlsc_error("underflow");
    end
end

integer cnt;
integer max_cnt;
always @(posedge clk) begin
    if(rst) begin
        cnt     = 0;
        max_cnt = 0;
    end else begin
        if(wr_push) begin
            cnt     = cnt + 1;
        end
        if(rd_pop) begin
            cnt     = cnt - 1;
        end
        if(cnt > max_cnt) begin
            max_cnt = cnt;
        end
    end
end

task report;
begin
    `dlsc_info("max usage: %0d%% (%0d/%0d)",((max_cnt*100)/DEPTHI),max_cnt,DEPTHI);
end
endtask

`include "dlsc_sim_bot.vh"
`endif


endmodule

