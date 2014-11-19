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
// Horizontal control logic for dlsc_window_front.

module dlsc_window_front_control_x #(
    parameter WINX          = 3,            // horizontal window size (odd; >= 1)
    parameter XB            = 10,           // bits for horizontal resolution
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
    input   wire    [XB-1:0]        cfg_x,

    // control in
    input   wire                    c0_en,

    // control out
    output  reg                     c0_en_y,
    output  reg                     c0_in_en,
    output  reg                     c1_out_en,
    output  reg                     c1_out_unmask,
    output  reg                     c1_out_last,
    output  reg                     c1_fill,
    output  reg                     c1_rd_en,
    output  reg                     c1_wr_en,
    output  reg     [XB-1:0]        c1_addr
);

`include "dlsc_util.vh"
`include "dlsc_synthesis.vh"

localparam WXB  =   EM_FILL     ? `dlsc_clog2_lower((WINX/2)  ,1) :
                    EM_REPEAT   ? `dlsc_clog2_lower((WINX/2)-1,1) :
                    EM_BAYER    ? `dlsc_clog2_lower((WINX/2)  ,1) :  // TODO
                  /*EM_NONE*/     `dlsc_clog2_lower( WINX     ,1);

generate
if(WINX <= 1) begin:GEN_WINX_1

    // TODO: may prefer to have user supply this directly
    wire [XB-1:0] cfg_x_m1_in = cfg_x - 1;
    wire [XB-1:0] cfg_x_m1;

    dlsc_cfgreg_slice #(
        .DATA   ( XB )
    ) dlsc_cfgreg_slice_cfg_x_m1 (
        .clk    ( clk ),
        .clk_en ( 1'b1 ),
        .rst    ( 1'b0 ),
        .in     ( cfg_x_m1_in ),
        .out    ( cfg_x_m1 )
    );

    `DLSC_PIPE_REG  reg  [XB-1:0]   c0_x;
    `DLSC_PIPE_REG  reg             c0_x_last;

    reg  [XB-1:0]   c0_next_x;
    reg             c0_next_x_last;

    always @* begin
        c0_next_x       = c0_x + 1;
        c0_next_x_last  = (c0_x == cfg_x_m1);
        if(c0_x_last) begin
            c0_next_x       = 0;
            c0_next_x_last  = 1'b0;
        end
    end

    always @(posedge clk) begin
        if(rst) begin
            c0_x        <= 0;
            c0_x_last   <= 1'b0;
            c0_in_en    <= 1'b1;
        end else if(c0_en) begin
            c0_x        <= c0_next_x;
            c0_x_last   <= c0_next_x_last;
            c0_in_en    <= 1'b1;
        end
    end

    always @* begin
        c0_en_y         = c0_x_last;
    end

    always @(posedge clk) begin
        c1_out_en       <= 1'b1;
        c1_out_unmask   <= 1'b1;
        c1_out_last     <= c0_x_last;
        c1_fill         <= 1'b0;
        c1_rd_en        <= 1'b1;
        c1_wr_en        <= 1'b1;
        c1_addr         <= c0_x;
    end

end else if(EM_FILL) begin:GEN_WINX_FILL

    // TODO

end else if(EM_REPEAT) begin:GEN_WINX_REPEAT

    // TODO: may prefer to have user supply this directly
    wire [XB-1:0] cfg_x_m2_in = cfg_x - 2;
    wire [XB-1:0] cfg_x_m2;

    dlsc_cfgreg_slice #(
        .DATA   ( XB )
    ) dlsc_cfgreg_slice_cfg_x_m2 (
        .clk    ( clk ),
        .clk_en ( 1'b1 ),
        .rst    ( 1'b0 ),
        .in     ( cfg_x_m2_in ),
        .out    ( cfg_x_m2 )
    );

    `DLSC_PIPE_REG  reg  [XB-1:0]   c0_x;
    `DLSC_PIPE_REG  reg             c0_x_last;
    `DLSC_PIPE_REG  reg  [WXB-1:0]  c0_wx;
    `DLSC_PIPE_REG  reg             c0_wx_last;
    `DLSC_PIPE_REG  reg  [2:0]      c0_xst;
    
    reg  [XB-1:0]   c0_next_x;
    reg             c0_next_x_last;
    reg  [WXB-1:0]  c0_next_wx;
    reg             c0_next_wx_last;
    reg             c0_next_in_en;
    reg             c0_next_en_y;
    reg  [2:0]      c0_next_xst;

    always @* begin
        c0_next_x       = 0;
        c0_next_x_last  = 1'b0;
        c0_next_wx      = 0;
        c0_next_wx_last = 1'b0;
        c0_next_xst     = {3{1'bx}};

        case(c0_xst)
            3'd0: begin
                // capture pixel [0]
                c0_next_xst     = ((WINX/2) > 1) ? 3'd1 : 3'd2;
            end
            3'd1: begin
                // repeat pixel [0]
                c0_next_wx      = c0_wx + 1;
                /* verilator lint_off WIDTH */
                c0_next_wx_last = (c0_wx == ((WINX/2)-3));
                /* verilator lint_on WIDTH */
                c0_next_xst     = c0_wx_last ? 3'd2 : 3'd1;
            end
            3'd2: begin
                // repeat pixel [0] and write it to memory
                c0_next_x       = c0_x + 1;
                c0_next_x_last  = (c0_x == cfg_x_m2);
                c0_next_xst     = 3'd3;
            end
            3'd3: begin
                // capture pixels [1] through [N-2] and write to memory
                c0_next_x       = c0_x + 1;
                c0_next_x_last  = (c0_x == cfg_x_m2);
                c0_next_xst     = c0_x_last ? 3'd4 : 3'd3;
            end
            3'd4: begin
                // capture pixel [N-1]
                c0_next_x       = c0_x;
                c0_next_xst     = ((WINX/2) > 1) ? 3'd5 : 3'd6;
            end
            3'd5: begin
                // repeat pixel [N-1]
                c0_next_x       = c0_x;
                c0_next_wx      = c0_wx + 1;
                /* verilator lint_off WIDTH */
                c0_next_wx_last = (c0_wx == ((WINX/2)-3));
                /* verilator lint_on WIDTH */
                c0_next_xst     = c0_wx_last ? 3'd6 : 3'd5;
            end
            3'd6: begin
                // repeat pixel [N-1] and write it to memory
                c0_next_xst     = 3'd0;
            end
            default: begin
                // illegal state
                $finish;
            end
        endcase

        if((WINX/2) <= 3) begin
            c0_next_wx      = 0;
        end
        if((WINX/2) <= 2) begin
            c0_next_wx_last = 1'b1;
        end

        c0_next_in_en   = (c0_next_xst == 3'd0) || (c0_next_xst == 3'd3) || (c0_next_xst == 3'd4);
        c0_next_en_y    = (c0_next_xst == 3'd6);
    end

    always @(posedge clk) begin
        if(rst) begin
            c0_x        <= 0;
            c0_x_last   <= 1'b0;
            c0_wx       <= 0;
            c0_wx_last  <= ((WINX/2) <= 2);
            c0_xst      <= 0;
            c0_in_en    <= 1'b1;
            c0_en_y     <= 1'b0;
        end else if(c0_en) begin
            c0_x        <= c0_next_x;
            c0_x_last   <= c0_next_x_last;
            c0_wx       <= c0_next_wx;
            c0_wx_last  <= c0_next_wx_last;
            c0_xst      <= c0_next_xst;
            c0_in_en    <= c0_next_in_en;
            c0_en_y     <= c0_next_en_y;
        end
    end

    always @(posedge clk) begin
        c1_out_en       <= 1'b1;
        c1_out_unmask   <= (c0_xst == 3'd2) || (c0_xst == 3'd3) || (c0_xst == 3'd4);
        c1_out_last     <= (c0_xst == 3'd4);
        c1_fill         <= 1'b0;
        c1_rd_en        <= 1'b1;
        c1_wr_en        <= (c0_xst == 3'd2) || (c0_xst == 3'd3) || (c0_xst == 3'd6);
        c1_addr         <= c0_x;
    end

end else if(EM_BAYER) begin:GEN_WINX_BAYER

    // TODO

end else begin:GEN_WINX_NONE

    // TODO

end
endgenerate

endmodule


