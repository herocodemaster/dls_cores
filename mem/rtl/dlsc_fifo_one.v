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
// 1-deep register slice with FIFO interface.

module dlsc_fifo_one #(
    parameter DATA          = 8,    // width of data in FIFO
    parameter ALMOST_FULL   = 0,    // assert almost_full when <= ALMOST_FULL free spaces remain (0 makes it equivalent to full)
    parameter ALMOST_EMPTY  = 0,    // assert almost_empty when <= ALMOST_EMPTY valid entries remain (0 makes it equivalent to empty)
    parameter FULL_IN_RESET = 0     // force full flags to be set when in reset
) (
    // system
    input   wire                clk,
    input   wire                rst,
    
    // input
    input   wire                wr_push,
    input   wire    [DATA-1:0]  wr_data,
    output  reg                 wr_full,
    output  wire                wr_almost_full,
    output  wire    [0:0]       wr_free,

    // output
    input   wire                rd_pop,
    output  reg     [DATA-1:0]  rd_data,
    output  reg                 rd_empty,
    output  wire                rd_almost_empty,
    output  wire    [0:0]       rd_count
);

assign          wr_almost_full  = (ALMOST_FULL ==0) ? wr_full  : 1'b1;
assign          wr_free         = !wr_full;

assign          rd_almost_empty = (ALMOST_EMPTY==0) ? rd_empty : 1'b1;
assign          rd_count        = !rd_empty;

always @(posedge clk) begin
    if(wr_push) begin
        rd_data     <= wr_data;
    end
end

reg             rst_done;

always @(posedge clk) begin
    if(rst) begin
        rd_empty    <= 1'b1;
        wr_full     <= FULL_IN_RESET ? 1'b1 : 1'b0;
        rst_done    <= FULL_IN_RESET ? 1'b0 : 1'b1;
    end else begin
        if(rd_pop && !wr_push) begin
            wr_full     <= 1'b0;
            rd_empty    <= 1'b1;
        end
        if(wr_push) begin
            // write after read, to support simultaneous push/pop when full
            wr_full     <= 1'b1;
            rd_empty    <= 1'b0;
        end
        if(FULL_IN_RESET) begin
            rst_done    <= 1'b1;
            if(!rst_done) begin
                wr_full     <= 1'b0;
            end
        end
    end
end


endmodule

