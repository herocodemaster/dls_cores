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
// Simple shallow FIFO. Uses dynamic shift-registers (found in most FPGAs)
// to simplify/reduce logic.

module dlsc_fifo_shiftreg #(
    parameter DATA          = 8,    // width of data in FIFO
    parameter DEPTH         = 0,    // depth of FIFO
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

    // output
    input   wire                rd_pop,
    output  wire    [DATA-1:0]  rd_data,
    output  reg                 rd_empty,
    output  wire                rd_almost_empty
);

`include "dlsc_clog2.vh"

localparam ADDR = `dlsc_clog2(DEPTH);


// read pointer

reg  [ADDR-1:0] addr;

wire            inc             =  wr_push && !rd_pop;
wire            dec             = !wr_push &&  rd_pop;

always @(posedge clk) begin
    if(rst) begin
        addr        <= {ADDR{1'b1}}; // -1 when empty
    end else begin
        if(inc) begin
            addr        <= addr + 1;
        end
        if(dec) begin
            addr        <= addr - 1;
        end
    end
end


// shift-register for contents of FIFO

dlsc_shiftreg #(
    .DATA       ( DATA ),
    .ADDR       ( ADDR ),
    .DEPTH      ( DEPTH ),
    .WARNINGS   ( 0 )
) dlsc_shiftreg_inst (
    .clk        ( clk ),
    .write_en   ( wr_push ),
    .write_data ( wr_data ),
    .read_addr  ( addr ),
    .read_data  ( rd_data )
);


// flags

reg             almost_empty;
reg             almost_full;
reg             rst_done;

assign          rd_almost_empty = (ALMOST_EMPTY==0) ? rd_empty : almost_empty;
assign          wr_almost_full  = (ALMOST_FULL ==0) ? wr_full  : almost_full;

/* verilator lint_off WIDTH */
always @(posedge clk) begin
    if(rst) begin

        // empty flags
        rd_empty        <= 1'b1;
        almost_empty    <= 1'b1;
        // full flags
        wr_full         <= FULL_IN_RESET ? 1'b1 : 1'b0;
        almost_full     <= FULL_IN_RESET ? 1'b1 : 1'b0;
        rst_done        <= FULL_IN_RESET ? 1'b0 : 1'b1;

    end else begin

        if(inc) begin
            rd_empty        <= 1'b0;
            wr_full         <= (addr == (DEPTH-2));

            if(addr == (      ALMOST_EMPTY-1) || (ALMOST_EMPTY  <= 0    )) begin
                almost_empty <= 1'b0;
            end
            if(addr == (DEPTH-ALMOST_FULL -2) || (ALMOST_FULL+1 >= DEPTH)) begin
                almost_full  <= 1'b1;
            end
        end

        if(dec) begin
            rd_empty        <= (addr == 0);
            wr_full         <= 1'b0;

            if(addr == (      ALMOST_EMPTY  )) begin
                almost_empty    <= 1'b1;
            end
            if(addr == (DEPTH-ALMOST_FULL -1)) begin
                almost_full     <= 1'b0;
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

