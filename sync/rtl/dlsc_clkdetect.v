// 
// Copyright (c) 2012, Daniel Strother < http://danstrother.com/ >
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
// Detects the presence of another clock.
//
// Works by passing a signal through the clk_monitor domain. The source signal
// is toggled each time it makes it back to the system clk domain. If the signal
// stops making it through the clk_monitor domain, we know that domain has
// stopped.
//
// The PROP parameter must be set carefully when monitoring slow clocks. It must
// account for the propagation delay through the synchronizer flops in each
// domain. In general:
//  PROP  >  3 * (1 + period[clk_monitor]/period[clk])

module dlsc_clkdetect #(
    parameter PROP          = 15,       // max allowable prop delay from clk through clk_monitor and back to clk domain
    parameter FILTER        = 15        // number of changes that must be detected before clock is declared active
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // clock status
    output  reg                     active,

    // monitored clock
    input   wire                    clk_monitor
);

`include "dlsc_clog2.vh"

localparam PB   = `dlsc_clog2(PROP);
localparam FB   = `dlsc_clog2(FILTER);

reg  [PB-1:0]   prop;
reg  [FB-1:0]   filter;

reg             tx;
wire            rx;

always @(posedge clk) begin
    if(rst) begin
        active      <= 1'b0;
        prop        <= 0;
        filter      <= 0;
        tx          <= 1'b0;
    end else begin
        if(tx == rx) begin
            // change made it through; update
            tx          <= !tx;
            prop        <= 0;
            if(filter == FILTER) begin
                active      <= 1'b1;
            end else begin
                filter      <= filter + 1;
            end
        end else begin
            if(prop == PROP) begin
                // timed out
                active      <= 1'b0;
                filter      <= 0;
            end else begin
                prop        <= prop + 1;
            end
        end
    end
end

// clk -> clk_monitor

wire monitor_tx;

dlsc_syncflop #(
    .DATA       ( 1 ),
) dlsc_syncflop_monitor (
    .in         ( tx ),
    .clk        ( clk_monitor ),
    .rst        ( 1'b0 ),
    .out        ( monitor_tx )
);

// clk_monitor -> clk

dlsc_syncflop #(
    .DATA       ( 1 ),
    .RESET      ( 1'b1 )
) dlsc_syncflop_clk (
    .in         ( monitor_tx ),
    .clk        ( clk ),
    .rst        ( rst ),
    .out        ( rx )
);

endmodule

