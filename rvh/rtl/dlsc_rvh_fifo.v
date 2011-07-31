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

module dlsc_rvh_fifo #(
    parameter DATA          = 8,    // width of data in FIFO
    parameter DEPTH         = 16,   // depth of FIFO
    parameter ALMOST_FULL   = 0,    // assert almost_full when <= ALMOST_FULL free spaces remain
    parameter ALMOST_EMPTY  = 0,    // assert almost_empty when <= ALMOST_EMPTY valid entries remain
    parameter FAST_FLAGS    = 1,    // disallow pessimistic flags
    parameter REGISTER      = 1     // register output
) (
    // system
    input   wire                clk,
    input   wire                rst,

    // source
    output  wire                in_ready,
    input   wire                in_valid,
    input   wire    [DATA-1:0]  in_data,
    output  wire                in_almost_full,

    // sink
    input   wire                out_ready,
    output  wire                out_valid,
    output  wire    [DATA-1:0]  out_data,
    output  wire                out_almost_empty
);

wire            full;
assign          in_ready        = !full;

wire            empty;
wire            pop;
wire [DATA-1:0] pop_data;

dlsc_fifo #(
    .DATA           ( DATA ),
    .DEPTH          ( DEPTH ),
    .ALMOST_FULL    ( ALMOST_FULL ),
    .ALMOST_EMPTY   ( ALMOST_EMPTY ),
    .FULL_IN_RESET  ( 1 ),
    .FAST_FLAGS     ( FAST_FLAGS )
) dlsc_fifo_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( in_ready && in_valid ),
    .wr_data        ( in_data ),
    .wr_full        ( full ),
    .wr_almost_full ( in_almost_full ),
    .wr_free        (  ),
    .rd_pop         ( pop ),
    .rd_data        ( pop_data ),
    .rd_empty       ( empty ),
    .rd_almost_empty( out_almost_empty ),
    .rd_count       (  )
);

generate
if(REGISTER>0) begin:GEN_REG

    reg             valid;
    reg  [DATA-1:0] data;

    assign          out_valid       = valid;
    assign          out_data        = data;
    assign          pop             = !empty && (!valid || out_ready);

    always @(posedge clk) begin
        if(rst) begin
            valid   <= 1'b0;
        end else begin
            if(out_ready) valid <= 1'b0;
            if(pop)       valid <= 1'b1;
        end
    end

    always @(posedge clk) begin
        if(pop) begin
            data    <= pop_data;
        end
    end

end else begin:GEN_NOREG

    assign          out_valid       = !empty;
    assign          out_data        = pop_data;
    assign          pop             = !empty && out_ready;

end
endgenerate

endmodule

