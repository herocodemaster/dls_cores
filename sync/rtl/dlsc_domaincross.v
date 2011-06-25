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
// Domain crossing is achieved with a cross-domain handshaking. This allows for
// arbitrary payloads to be transferred without need for special encodings (e.g.
// gray code), but it yields an inconsistent delay between input and output.
//
// For payloads that can be gray coded (e.g. FIFO counters), you can achieve
// more consistent and lower latency by using a more conventional dlsc_syncflop.

module dlsc_domaincross #(
    parameter   DATA    = 32,
    parameter   RESET   = {DATA{1'b0}}
) (
    // source domain
    input   wire                in_clk,
    input   wire                in_rst,
    input   wire    [DATA-1:0]  in_data,

    // consumer domain
    input   wire                out_clk,
    input   wire                out_rst,
    output  wire    [DATA-1:0]  out_data
);

// _rvh is essentially the same functionality; no point in maintaining two
// nearly-identical modules..
dlsc_domaincross_rvh #(
    .DATA       ( DATA ),
    .RESET      ( RESET )
) dlsc_domaincross_rvh_inst (
    .in_clk     ( in_clk ),
    .in_rst     ( in_rst ),
    .in_data    ( in_data ),
    .in_ready   (  ),
    .in_valid   ( 1'b1 ),
    .out_clk    ( out_clk ),
    .out_rst    ( out_rst ),
    .out_data   ( out_data ),
    .out_ready  ( 1'b1 ),
    .out_valid  (  )
);

endmodule

