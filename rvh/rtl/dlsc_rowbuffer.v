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
// An asynchronous FIFO with ready/valid handshaking for use on interfaces that
// are row/block-oriented (e.g. image processing). Can perform conversion
// between blocks that produce/consume a different number of rows in parallel.
// (e.g. one block may produce 2 rows at a time, while the other may consume 4
// rows at a time; with IN_ROWS = 2 and OUT_ROWS = 4, this block can interface
// between them). Conversion ratios must be an integer (if IN_ROWS > OUT_ROWS,
// then IN_ROWS is an integer multiple of OUT_ROWS, and vice-versa).

module dlsc_rowbuffer #(
    parameter ROW_WIDTH     = 537,          // width of each row
    parameter BUF_DEPTH     = ROW_WIDTH,    // depth of buffer (BUF_DEPTH >= ROW_WIDTH)
    parameter IN_ROWS       = 1,            // number of rows to input in parallel
    parameter OUT_ROWS      = 1,            // number of rows to output in parallel
    parameter DATA          = 16,           // width of each piece of data
    parameter ALMOST_FULL   = 0,
    // derived; don't touch
    parameter DATA_IR       = (DATA*IN_ROWS),
    parameter DATA_OR       = (DATA*OUT_ROWS)
) (

    // ** input **

    // system
    input   wire                    in_clk,
    input   wire                    in_rst,

    // handshake
    output  wire                    in_ready,
    input   wire                    in_valid,

    // data
    input   wire    [DATA_IR-1:0]   in_data,

    // status
    output  wire                    in_almost_full,


    // ** output **

    // system
    input   wire                    out_clk,
    input   wire                    out_rst,

    // handshake
    input   wire                    out_ready,
    output  wire                    out_valid,

    // data
    output  wire    [DATA_OR-1:0]   out_data

);


localparam HI       = (IN_ROWS >= OUT_ROWS) ?  IN_ROWS : OUT_ROWS;
localparam LO       = (IN_ROWS >= OUT_ROWS) ? OUT_ROWS :  IN_ROWS;
localparam RATIO    = HI / LO;
localparam DATA_LO  = (DATA*LO);


`ifdef SIMULATION
/* verilator coverage_off */
initial begin
    if(IN_ROWS > OUT_ROWS) begin
        if((IN_ROWS % OUT_ROWS) != 0) begin
            $display("[%m] *** ERROR *** when IN_ROWS > OUT_ROWS, IN_ROWS (%0d) must be integer multiple of OUT_ROWS (%0d)", IN_ROWS, OUT_ROWS);
        end
    end else if(IN_ROWS < OUT_ROWS) begin
        if((OUT_ROWS % IN_ROWS) != 0) begin
            $display("[%m] *** ERROR *** when OUT_ROWS > IN_ROWS, OUT_ROWS (%0d) must be integer multiple of IN_ROWS (%0d)", OUT_ROWS, IN_ROWS);
        end
    end
    if(BUF_DEPTH < ROW_WIDTH) begin
        $display("[%m] *** ERROR *** must have BUF_DEPTH (%0d) >= ROW_WIDTH (%0d)", BUF_DEPTH, ROW_WIDTH);
    end
end
/* verilator coverage_on */
`endif


generate
    if(IN_ROWS >= OUT_ROWS) begin:GEN_COMBINER

        dlsc_rowbuffer_combiner #(
            .ROW_WIDTH      ( ROW_WIDTH ),
            .BUF_DEPTH      ( BUF_DEPTH ),
            .ROWS           ( RATIO ),
            .DATA           ( DATA_LO ),
            .ALMOST_FULL    ( ALMOST_FULL )
        ) dlsc_rowbuffer_combiner_inst (
            .in_clk         ( in_clk ),
            .in_rst         ( in_rst ),
            .in_ready       ( in_ready ),
            .in_valid       ( in_valid ),
            .in_data        ( in_data ),
            .in_almost_full ( in_almost_full ),
            .out_clk        ( out_clk ),
            .out_rst        ( out_rst ),
            .out_ready      ( out_ready ),
            .out_valid      ( out_valid ),
            .out_data       ( out_data )
        );

    end else begin:GEN_SPLITTER

        dlsc_rowbuffer_splitter #(
            .ROW_WIDTH      ( ROW_WIDTH ),
            .BUF_DEPTH      ( BUF_DEPTH ),
            .ROWS           ( RATIO ),
            .DATA           ( DATA_LO )
        ) dlsc_rowbuffer_splitter_inst (
            .in_clk         ( in_clk ),
            .in_rst         ( in_rst ),
            .in_ready       ( in_ready ),
            .in_valid       ( in_valid ),
            .in_data        ( in_data ),
            .out_clk        ( out_clk ),
            .out_rst        ( out_rst ),
            .out_ready      ( out_ready ),
            .out_valid      ( out_valid ),
            .out_data       ( out_data )
        );

        // TODO
        assign in_almost_full = 1'b0;

    end
endgenerate

endmodule

