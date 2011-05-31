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
// Provides an asynchronous clock domain crossing for an arbitrary data payload.
// Input data will arrive in the output domain some number of cycles later, and
// is guaranteed to be updated atomically. No guarantees are made about data
// synchronized through different instantiations of dlsc_domaincross.
//
// No reset functionality is provided. If this is used on control signals, the
// parent module must ensure that resets in both clock domains remain asserted
// long enough for reset values to propagate from source to consumer domain.
//
// Domain crossing is achieved with a cross-domain handshaking. This allows for
// arbitrary payloads to be transferred without need for special encodings (e.g.
// gray code), but it yields an inconsistent delay between input and output.
//
// For payloads that can be gray coded (e.g. FIFO counters), you can achieve
// more consistent and lower latency by using a more conventional dlsc_syncflop.

module dlsc_domaincross #(
    parameter   DATA    = 32
) (
    // source domain
    input   wire                in_clk,
    input   wire    [DATA-1:0]  in_data,

    // consumer domain
    input   wire                out_clk,
    output  wire    [DATA-1:0]  out_data
);

`include "dlsc_synthesis.vh"

// ** input **
`DLSC_KEEP_REG reg  in_flag    = 1'b0;
`DLSC_KEEP_REG reg  in_flagx   = 1'b0;
wire in_ack;
wire in_en = (in_flag == in_ack);

always @(posedge in_clk) begin
    if(in_en) begin
        // send and flag new value once acked
        in_flag     <= !in_flag;
        in_flagx    <= !in_flag;
    end
end


// ** output **
`DLSC_KEEP_REG reg  out_ack    = 1'b0;
`DLSC_KEEP_REG reg  out_ackx   = 1'b0;
wire out_flag;
wire out_en = (out_flag != out_ack);

always @(posedge out_clk) begin
    if(out_en) begin
        // consume and ack new value when flagged
        out_ack     <= !out_ack;
        out_ackx    <= !out_ack;
    end
end


// ** data crossing **

dlsc_domaincross_slice dlsc_domaincross_slice_inst[DATA-1:0] (
    .in_clk     ( in_clk ),
    .in_en      ( in_en ),
    .in_data    ( in_data ),
    .out_clk    ( out_clk ),
    .out_en     ( out_en ),
    .out_data   ( out_data )
);


// ** control synchronization **

dlsc_syncflop_slice dlsc_syncflop_slice_inst_in (
    .in     ( out_ackx ),
    .clk    ( in_clk ),
    .out    ( in_ack )
);

dlsc_syncflop_slice dlsc_syncflop_slice_inst_out (
    .in     ( in_flagx ),
    .clk    ( out_clk ),
    .out    ( out_flag )
);


endmodule

