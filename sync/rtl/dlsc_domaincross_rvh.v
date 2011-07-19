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
// Provides an asynchronous clock domain crossing for an arbitrary data payload
// with ready/valid handshaking. Lower latency than an async FIFO, but poor
// throughput. Good for command channels.

module dlsc_domaincross_rvh #(
    parameter   DATA    = 32,
    parameter   RESET   = {DATA{1'b0}},
    parameter   RESET_ON_TRANSFER = 0       // reset out_data after it is accepted
) (
    // source domain
    input   wire                in_clk,
    input   wire                in_rst,

    output  wire                in_ready,
    input   wire                in_valid,
    input   wire    [DATA-1:0]  in_data,

    // consumer domain
    input   wire                out_clk,
    input   wire                out_rst,

    input   wire                out_ready,
    output  reg                 out_valid,
    output  wire    [DATA-1:0]  out_data
);

`include "dlsc_synthesis.vh"

// ** input **
`DLSC_KEEP_REG reg  in_flag    = 1'b0;
`DLSC_KEEP_REG reg  in_flagx   = 1'b0;

wire   in_ack;
assign in_ready = (in_flag == in_ack);
wire   in_en    = (in_ready && in_valid);

always @(posedge in_clk) begin
    if(in_rst) begin
        in_flag     <= 1'b0;
        in_flagx    <= 1'b0;
    end else if(in_en) begin
        // send and flag new value once acked
        in_flag     <= !in_flag;
        in_flagx    <= !in_flag;
    end
end


// ** output **
`DLSC_KEEP_REG reg  out_ack    = 1'b0;
`DLSC_KEEP_REG reg  out_ackx   = 1'b1;

wire out_flag;
wire out_en         = (out_flag != out_ack) && (out_ready || !out_valid);
wire out_rst_data   = out_rst || (RESET_ON_TRANSFER && !out_en && out_ready && out_valid);

always @(posedge out_clk) begin
    if(out_rst) begin
        out_ack     <= 1'b0;
        out_ackx    <= 1'b1;
        out_valid   <= 1'b0;
    end else begin
        if(out_ready) begin
            out_valid   <= 1'b0;
        end
        if(out_en) begin
            // consume and ack new value when flagged
            out_ack     <= !out_ack;
            out_ackx    <= !out_ack;
            out_valid   <= 1'b1;
        end else begin
            out_ackx    <=  out_ack;
        end
    end
end


// ** data crossing **

generate
    genvar j;
    for(j=0;j<DATA;j=j+1) begin:GEN_SLICES
        dlsc_domaincross_slice #(
            .RESET      ( RESET[j] )
        ) dlsc_domaincross_slice_inst (
            .in_clk     ( in_clk ),
            .in_rst     ( in_rst ),
            .in_en      ( in_en ),
            .in_data    ( in_data[j] ),
            .out_clk    ( out_clk ),
            .out_rst    ( out_rst_data ),
            .out_en     ( out_en ),
            .out_data   ( out_data[j] )
        );
    end
endgenerate


// ** control synchronization **

dlsc_syncflop #(
    .DATA   ( 1 ),
    .RESET  ( 1'b1 )
) dlsc_syncflop_inst_in (
    .in     ( out_ackx ),
    .clk    ( in_clk ),
    .rst    ( in_rst ),
    .out    ( in_ack )
);

dlsc_syncflop #(
    .DATA   ( 1 ),
    .RESET  ( 1'b0 )
) dlsc_syncflop_inst_out (
    .in     ( in_flagx ),
    .clk    ( out_clk ),
    .rst    ( out_rst ),
    .out    ( out_flag )
);

endmodule

