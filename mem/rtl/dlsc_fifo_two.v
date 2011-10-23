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
// 2-deep register slice with FIFO interface.

module dlsc_fifo_two #(
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
    output  reg                 wr_almost_full,
    output  reg     [1:0]       wr_free,

    // output
    input   wire                rd_pop,
    output  wire    [DATA-1:0]  rd_data,
    output  reg                 rd_empty,
    output  reg                 rd_almost_empty,
    output  reg     [1:0]       rd_count
);

`include "dlsc_synthesis.vh"

`DLSC_NO_SHREG reg [DATA-1:0] buf_data;
`DLSC_NO_SHREG reg [DATA-1:0] out_data;

assign              rd_data     = out_data;

reg                 buf_valid;
reg                 out_valid;

reg                 next_buf_valid;
reg                 next_out_valid;

always @* begin
    next_buf_valid  = buf_valid;
    next_out_valid  = out_valid;

    if(rd_pop) begin
        next_out_valid  = buf_valid;
        next_buf_valid  = 1'b0;
    end
    if(wr_push) begin
        if(!out_valid || (rd_pop && !buf_valid)) begin
            next_out_valid  = 1'b1;
        end else begin
            next_buf_valid  = 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(rd_pop && buf_valid) begin
        out_data    <= buf_data;
    end
    if(wr_push) begin
        if(!out_valid || (rd_pop && !buf_valid)) begin
            out_data    <= wr_data;
        end else begin
            buf_data    <= wr_data;
        end
    end
end

always @(posedge clk) begin
    if(rst) begin
        wr_full         <= FULL_IN_RESET ? 1'b1 : 1'b0;
        wr_almost_full  <= FULL_IN_RESET ? 1'b1 : 1'b0;
        wr_free         <= 2'd2;
        rd_empty        <= 1'b1;
        rd_almost_empty <= 1'b1;
        rd_count        <= 2'd0;
        buf_valid       <= 1'b0;
        out_valid       <= 1'b0;
    end else begin
        buf_valid       <= next_buf_valid;
        out_valid       <= next_out_valid;
        case({next_buf_valid,next_out_valid})
            2'b00: begin
                wr_full         <= 1'b0;
                wr_almost_full  <= (ALMOST_FULL>=2);
                wr_free         <= 2'd2;
                rd_empty        <= 1'b1;
                rd_almost_empty <= 1'b1;
                rd_count        <= 2'd0;
            end
            2'b01: begin
                wr_full         <= 1'b0;
                wr_almost_full  <= (ALMOST_FULL>=1);
                wr_free         <= 2'd1;
                rd_empty        <= 1'b0;
                rd_almost_empty <= (ALMOST_EMPTY>=1);
                rd_count        <= 2'd1;
            end
            2'b10: begin
`ifdef SIMULATION
                // unreachable state
                $stop;
`endif
            end
            2'b11: begin
                wr_full         <= 1'b1;
                wr_almost_full  <= 1'b1;
                wr_free         <= 2'd0;
                rd_empty        <= 1'b0;
                rd_almost_empty <= (ALMOST_EMPTY>=2);
                rd_count        <= 2'd2;
            end
        endcase
    end
end

endmodule

