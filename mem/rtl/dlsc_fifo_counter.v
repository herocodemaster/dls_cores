// 
// Copyright (c) 2012, Daniel Strother < http://danstrother.com/ >
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
// Counter with FIFO interface.

module dlsc_fifo_counter (
    // system
    clk,
    rst,
    // input
    wr_push,
    wr_full,
    wr_almost_full,
    wr_free,
    // output
    rd_pop,
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

parameter ALMOST_FULL   = 0;                    // assert almost_full when <= ALMOST_FULL free spaces remain
parameter ALMOST_EMPTY  = 0;                    // assert almost_empty when <= ALMOST_EMPTY valid entries remain
parameter COUNT         = 0;                    // enable rd_count port
parameter FREE          = 0;                    // enable wr_free port
parameter FAST_FLAGS    = 1;                    // disallow pessimistic flags
parameter FULL_IN_RESET = 0;                    // force full flags to be set when in reset


// ** Ports **

// system
input   wire                clk;
input   wire                rst;

// input
input   wire                wr_push;
output  reg                 wr_full;
output  wire                wr_almost_full;
output  wire    [ADDR:0]    wr_free;

// output
input   wire                rd_pop;
output  reg                 rd_empty;
output  wire                rd_almost_empty;
output  wire    [ADDR:0]    rd_count;


// ** Flags **

reg  [ADDR:0]   cnt;        // 1 extra bit, since we want to store [0,DEPTHI] (not just DEPTHI-1)
reg  [ADDR:0]   free;
reg             almost_empty;
reg             almost_full;
reg             rst_done;

assign          rd_almost_empty = (ALMOST_EMPTY==0) ? rd_empty : almost_empty;
assign          wr_almost_full  = (ALMOST_FULL ==0) ? wr_full  : almost_full;

assign          rd_count        = COUNT ? cnt  : {(ADDR+1){1'bx}};
assign          wr_free         = FREE  ? free : {(ADDR+1){1'bx}};

wire            inc             =  wr_push && !rd_pop;
wire            dec             = !wr_push &&  rd_pop;

/* verilator lint_off WIDTH */
always @(posedge clk) begin
    if(rst) begin
        // counts
        cnt             <= 0;
        free            <= DEPTHI;
        // empty flags
        rd_empty        <= 1'b1;
        almost_empty    <= 1'b1;
        // full flags
        wr_full         <= FULL_IN_RESET ? 1'b1 : 1'b0;
        almost_full     <= FULL_IN_RESET ? 1'b1 : 1'b0;
        rst_done        <= FULL_IN_RESET ? 1'b0 : 1'b1;
    end else begin

        // pushed; count increments
        if(inc) begin
            cnt             <= cnt + 1;
            free            <= free - 1;
            wr_full         <= (cnt == (DEPTHI-1)); // cnt will be DEPTHI (full)
            if(cnt == (       ALMOST_EMPTY  )) almost_empty <= 1'b0;
            if(cnt == (DEPTHI-ALMOST_FULL -1)) almost_full  <= 1'b1;
        end

        // popped; count decrements
        if(dec) begin
            cnt             <= cnt - 1;
            free            <= free + 1;
            wr_full         <= 1'b0;                // can't be full on pop
            if(cnt == (       ALMOST_EMPTY+1)) almost_empty <= 1'b1;
            if(cnt == (DEPTHI-ALMOST_FULL   )) almost_full  <= 1'b0;
        end

        if(FAST_FLAGS) begin
            if(inc) begin
                rd_empty    <= 1'b0;
            end
            if(dec) begin
                rd_empty    <= (cnt == 1);
            end
        end else begin
            // special empty flag handling..
            // (since the RAM doesn't support simultaneously reading from the same
            //  address that is being written to)
            if(cnt == 1) begin
                if(rd_pop) begin
                    rd_empty    <= 1'b1;
                end else begin
                    rd_empty    <= 1'b0;
                end
            end
        end

        if(FULL_IN_RESET) begin
            rst_done    <= 1'b1;
            if(!rst_done) begin
                wr_full     <= 1'b0;
                almost_full <= 1'b0;
            end
        end

    end
end
/* verilator lint_on WIDTH */

endmodule


