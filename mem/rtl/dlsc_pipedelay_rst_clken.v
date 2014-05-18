// 
// Copyright (c) 2013, Daniel Strother < http://danstrother.com/ >
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
//
// Implements an arbitrary pipeline delay with resettable contents.
// This module supports three different reset modes, selected by FAST_RESET.
// In all modes, 'out_data' is always driven to RESET 1 cycle after 'rst' is
// asserted. The modes differ in their requirements regarding the 'rst' and
// 'in_data' input signals.
//
// FAST_RESET = 1:
//      Module can accept a 'rst' pulse that is only 1 cycle long. In this mode,
//      the module does NOT infer shift-registers in most FPGAs.
// FAST_RESET = 0:
//      'rst' must be held asserted for at least 33 cycles. 'in_data' does not
//      have to be driven to a specific value while 'rst' is asserted.
// FAST_RESET = -1:
//      When 'rst' is asserted, 'in_data' must also be driven to RESET. 'rst' must
//      be held asserted for at least 33 cycles after 'in_data' is driven to RESET.
//      These requirements are not always easy to meet, so this mode is generally
//      reserved for special low-level applications.
//

module dlsc_pipedelay_rst_clken #(
    parameter DELAY         = 1,            // delay from input to output
    parameter DATA          = 1,            // width of delayed data
    parameter RESET         = {DATA{1'b0}}, // reset value for data
    parameter FAST_RESET    = 1             // when set, indicates that a single-cycle rst is expected
) (
    input   wire                clk,
    input   wire                clk_en,
    input   wire                rst,

    input   wire    [DATA-1:0]  in_data,

    output  wire    [DATA-1:0]  out_data
);

`include "dlsc_util.vh"

`dlsc_static_assert_range(FAST_RESET,-1,1)

integer i;
genvar j;

localparam SLICE_DELAY  = ((DATA%2) == 0) ? 17 : 33;    // for even DATA, use delay of only 16 to take advantage of dual SRL16
localparam DELAYI       = (FAST_RESET==0) ? (DELAY-1) : (DELAY);
localparam SLICES       = (DELAYI+SLICE_DELAY-1)/SLICE_DELAY;
localparam LAST_DELAY   = DELAYI - ((SLICES-1)*SLICE_DELAY);

generate
if(DELAY == 0) begin:GEN_DELAY0

    assign out_data     = in_data;

end else if(DELAY == 1) begin:GEN_DELAY1

    reg [DATA-1:0] out_data_r0;

    always @(posedge clk) begin
        if(rst) begin
            out_data_r0     <= RESET;
        end else if(clk_en) begin
            out_data_r0     <= in_data;
        end
    end
    assign out_data = out_data_r0;

end else begin:GEN_DELAYN
    if(FAST_RESET>0) begin:GEN_FAST_RESET
    
        reg [DATA-1:0] out_data_r [DELAY-2:0];
        reg [DATA-1:0] out_data_rn;

        always @(posedge clk) begin
            if(rst) begin
                out_data_rn     <= RESET;
                for(i=(DELAY-2);i>=0;i=i-1) begin
                    out_data_r[i]   <= RESET;
                end
            end else if(clk_en) begin
                out_data_rn     <= out_data_r[DELAY-2];
                
                for(i=(DELAY-2);i>0;i=i-1) begin
                    out_data_r[i]   <= out_data_r[i-1];
                end
                out_data_r[0]   <= in_data;
                    
            end
        end
        assign out_data = out_data_rn;

    end else begin:GEN_SLOW_RESET

        wire clk_en_i = clk_en || rst;

        wire [DATA-1:0] cascade [SLICES:0];
        assign out_data = cascade[SLICES];

        if(FAST_RESET==0) begin:GEN_REG_IN

            reg [DATA-1:0] in_data_r;

            always @(posedge clk) begin
                if(rst) begin
                    in_data_r <= RESET;
                end else if(clk_en) begin
                    in_data_r <= in_data;
                end
            end
        
            assign cascade[0] = in_data_r;

        end else begin:GEN_NO_REG_IN

            assign cascade[0] = in_data;

        end

        for(j=0;j<SLICES;j=j+1) begin:GEN_SLICES

            dlsc_pipedelay_rst_clken_slice #(
                .DELAY      ( (j==(SLICES-1)) ? LAST_DELAY : SLICE_DELAY ),
                .DATA       ( DATA ),
                .RESET      ( RESET )
            ) dlsc_pipedelay_rst_clken_slice (
                .clk        ( clk ),
                .clk_en     ( clk_en_i ),
                .rst        ( rst ),
                .in_data    ( cascade[j  ] ),
                .out_data   ( cascade[j+1] )
            );

        end

    end
end
endgenerate

endmodule

