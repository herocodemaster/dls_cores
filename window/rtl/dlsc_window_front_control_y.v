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
// Vertical control logic for dlsc_window_front.

module dlsc_window_front_control_y #(
    parameter WINY          = 3,            // vertical window size (odd; >= 1)
    parameter YB            = 10,           // bits for vertical resolution
    // edge mode (decoded; one-hot)
    parameter EM_FILL       = 0,
    parameter EM_REPEAT     = 0,
    parameter EM_BAYER      = 0,
    parameter EM_NONE       = 1
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // config
    input   wire    [YB-1:0]        cfg_y,

    // control in
    input   wire                    c0_en,
    
    // control out
    output  reg                     c0_in_en,
    output  reg                     c1_out_en,
    output  reg                     c1_out_unmask,
    output  reg                     c1_out_last,
    output  reg                     c1_prime,
    output  reg                     c1_post
);

`include "dlsc_util.vh"
`include "dlsc_synthesis.vh"

localparam WYB  =   `dlsc_clog2_lower((WINY/2)-1,1);

generate
if(WINY <= 1) begin:GEN_WINY_1

    // TODO

end else if(EM_FILL || EM_REPEAT) begin:GEN_WINY_FILL_REPEAT

    // TODO: may prefer to have user supply this directly
    wire [YB-1:0] cfg_y_m1_in = cfg_y - 1;
    wire [YB-1:0] cfg_y_m1;

    dlsc_cfgreg_slice #(
        .DATA   ( YB )
    ) dlsc_cfgreg_slice_cfg_y_m1 (
        .clk    ( clk ),
        .clk_en ( 1'b1 ),
        .rst    ( 1'b0 ),
        .in     ( cfg_y_m1_in ),
        .out    ( cfg_y_m1 )
    );

    `DLSC_PIPE_REG  reg  [YB-1:0]   c0_y;
    `DLSC_PIPE_REG  reg             c0_y_last;
    `DLSC_PIPE_REG  reg             c0_wy_last;
    `DLSC_PIPE_REG  reg  [1:0]      c0_yst;
    `DLSC_PIPE_REG  reg             c0_prime;

    reg  [YB-1:0]   c0_next_y;
    reg             c0_next_y_last;
    reg             c0_next_wy_last;
    reg  [1:0]      c0_next_yst;
    reg             c0_next_in_en;

    always @* begin
        c0_next_y       = c0_y + 1;
        c0_next_y_last  = (c0_y == cfg_y_m1);
        /* verilator lint_off WIDTH */
        c0_next_wy_last = (c0_y[WYB-1:0] == ((WINY/2)-2));
        /* verilator lint_on WIDTH */
        c0_next_yst     = 2'bxx;

        case(c0_yst)
            2'd0: begin
                // priming row buffer before producing any output
                c0_next_yst     = c0_wy_last ? 2'd1 : 2'd0;
            end
            2'd1: begin
                // producing output from buffer+input
                c0_next_yst     = c0_y_last ? 2'd2 : 2'd1;
                if(c0_y_last) begin
                    c0_next_y       = 0;
                    c0_next_y_last  = 1'b0;
                    c0_next_wy_last = 1'b0;
                end
            end
            2'd2: begin
                // producing unmasked output from buffer
                c0_next_yst     = c0_wy_last ? 2'd3 : 2'd2;
            end
            2'd3: begin
                // producing masked output from buffer
                // stuck in this state until reset
                c0_next_y       = 0;
                c0_next_y_last  = 1'b0;
                c0_next_wy_last = 1'b0;
                c0_next_yst     = 2'd3;
            end
            default: begin
                // illegal state
                $finish;
            end
        endcase

        if((WINY/2) <= 1) begin
            c0_next_wy_last = 1'b1;
        end

        c0_next_in_en       = (c0_next_yst == 2'd0) || (c0_next_yst == 2'd1);
    end

    always @(posedge clk) begin
        if(rst) begin
            c0_y        <= 0;
            c0_y_last   <= 1'b0;
            c0_wy_last  <= ((WINY/2) <= 1);
            c0_yst      <= 2'd0;
            c0_in_en    <= 1'b1;
            c0_prime    <= 1'b1;
        end else if(c0_en) begin
            c0_y        <= c0_next_y;
            c0_y_last   <= c0_next_y_last;
            c0_wy_last  <= c0_next_wy_last;
            c0_yst      <= c0_next_yst;
            c0_in_en    <= c0_next_in_en;
            c0_prime    <= 1'b0;
        end
    end

    always @(posedge clk) begin
        c1_out_en       <= (c0_yst == 2'd1) || (c0_yst == 2'd2) || (c0_yst == 2'd3);
        c1_out_unmask   <= (c0_yst == 2'd1) || (c0_yst == 2'd2);
        c1_out_last     <= c0_wy_last &&       (c0_yst == 2'd2);
        c1_post         <=                     (c0_yst == 2'd2) || (c0_yst == 2'd3);
        c1_prime        <= c0_prime;
    end

end else if(EM_BAYER) begin:GEN_BAYER

    // TODO

end else begin:GEN_NONE

    // TODO

end

endgenerate

endmodule

