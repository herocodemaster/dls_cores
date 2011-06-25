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
// Reset synchronizer and fanout buffer for multiple clock domains. All domains
// are guaranteed to be in reset before any domain is released from reset.

module dlsc_rstsync #(
    parameter DOMAINS   = 1,
    parameter DEPTH     = 4
) (
    input   wire                    rst_in,     // asynchronous reset input
    input   wire    [DOMAINS-1:0]   clk,        // clocks to synchronize resets to
    output  wire    [DOMAINS-1:0]   rst_out     // synchronous reset outputs
);

generate
    genvar j;

    if(DOMAINS==1) begin:GEN_DOMAINS1

        // for a single domain, we only need a slice
        dlsc_rstsync_slice #(
            .DEPTH      ( DEPTH )
        ) dlsc_rstsync_slice_inst (
            .clk        ( clk[0] ),
            .rst_in     ( rst_in ),
            .rst_out    ( rst_out[0] )
        );

    end else begin:GEN_DOMAINSN

        // synchronized rst_in in each domain
        wire [DOMAINS-1:0] rst_domains;

        // aggregate of all domain resets
        // (used to create the actual reset going into each rstsync_slice)
        wire rst_all = |rst_domains;

        for(j=0;j<DOMAINS;j=j+1) begin:GEN_SLICES

            // synchronize incoming reset to each domain
            dlsc_syncflop #(
                .RESET      ( 1'b1 )
            ) dlsc_syncflop_inst (
                .clk        ( clk[j] ),
                .rst        ( rst_in ),
                .in         ( 1'b0 ),
                .out        ( rst_domains[j] )
            );

            // synchronize aggregate reset to each domain
            dlsc_rstsync_slice #(
                .DEPTH      ( DEPTH )
            ) dlsc_rstsync_slice_inst (
                .clk        ( clk[j] ),
                .rst_in     ( rst_all ),
                .rst_out    ( rst_out[j] )
            );

        end

    end
endgenerate


endmodule

