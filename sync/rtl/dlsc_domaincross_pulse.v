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
// Synchronizes a pulse on one clock domain into a single-cycle pulse on
// a different clock domain

module dlsc_domaincross_pulse (
    // source domain
    input   wire                in_clk,
    input   wire                in_rst,
    input   wire                in_pulse,

    // consumer domain
    input   wire                out_clk,
    input   wire                out_rst,
    output  wire                out_pulse
);

// find in_pulse edges

reg         in_pulse_prev;

always @(posedge in_clk) begin
    in_pulse_prev <= in_pulse;
end

// synchronize

wire        in_ready;
wire        in_valid  = !in_pulse_prev && in_pulse;

dlsc_domaincross_rvh #(
    .DATA           ( 1 )
) dlsc_domaincross_rvh_inst (
    .in_clk         ( in_clk ),
    .in_rst         ( in_rst ),
    .in_ready       ( in_ready ),
    .in_valid       ( in_valid ),
    .in_data        ( 1'b0 ),
    .out_clk        ( out_clk ),
    .out_rst        ( out_rst ),
    .out_ready      ( 1'b1 ),
    .out_valid      ( out_pulse ),
    .out_data       (  )
);


// simulation checks

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @(posedge in_clk) begin
    if(!in_rst && in_valid && !in_ready) begin
        `dlsc_warn("lost in_pulse");
    end
end

`include "dlsc_sim_bot.vh"
`endif


endmodule

