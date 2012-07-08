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
// Synchronizes single-cycle pulses on one clock domain into single-cycle
// pulses on a different clock domain.
//
// BYPASS parameter turns module into a wire (use for simplifying parameterized
// async crossings).

module dlsc_domaincross_pulse #(
    parameter BYPASS    = 0,
    parameter DEPTH     = 1         // number of pulses that can be buffered internally
) (
    // source domain
    input   wire                in_clk,
    input   wire                in_rst,
    input   wire                in_pulse,

    // consumer domain
    input   wire                out_clk,
    input   wire                out_rst,
    output  wire                out_pulse
);

`include "dlsc_clog2.vh"
localparam ADDR = `dlsc_clog2(DEPTH);

generate
if(BYPASS) begin:GEN_BYPASS

    assign out_pulse = in_pulse;

end else begin:GEN_ASYNC

    wire        in_ready;

    if(DEPTH<=1) begin:GEN_SHALLOW
        dlsc_domaincross_rvh #(
            .BYPASS         ( BYPASS ),
            .DATA           ( 1 )
        ) dlsc_domaincross_rvh (
            .in_clk         ( in_clk ),
            .in_rst         ( in_rst ),
            .in_ready       ( in_ready ),
            .in_valid       ( in_pulse ),
            .in_data        ( 1'b0 ),
            .out_clk        ( out_clk ),
            .out_rst        ( out_rst ),
            .out_ready      ( 1'b1 ),
            .out_valid      ( out_pulse ),
            .out_data       (  )
        );
    end else begin:GEN_DEPTH

        // use async FIFO as a cross-domain counter of sorts
        // TODO: do something more efficient
        
        wire        in_full;
        assign      in_ready    = !in_full;

        wire        out_empty;
        assign      out_pulse   = !out_empty;

        dlsc_fifo_async #(
            .DATA           ( 1 ),
            .ADDR           ( ADDR )
        ) dlsc_fifo_async (
            .wr_clk         ( in_clk ),
            .wr_rst         ( in_rst ),
            .wr_push        ( in_ready && in_pulse ),
            .wr_data        ( 1'b0 ),
            .wr_full        ( in_full ),
            .wr_almost_full (  ),
            .wr_free        (  ),
            .rd_clk         ( out_clk ),
            .rd_rst         ( out_rst ),
            .rd_pop         ( out_pulse ),
            .rd_data        (  ),
            .rd_empty       ( out_empty ),
            .rd_almost_empty (  ),
            .rd_count       (  )
        );
    end

    // simulation checks

    `ifdef DLSC_SIMULATION
    `include "dlsc_sim_top.vh"

    always @(posedge in_clk) begin
        if(!in_rst && in_pulse && !in_ready) begin
            `dlsc_error("lost pulse");
        end
    end

    `include "dlsc_sim_bot.vh"
    `endif

end
endgenerate

endmodule

