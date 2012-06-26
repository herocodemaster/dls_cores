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
// VNG control and column buffering.

module dlsc_demosaic_vng6_control #(
    parameter BITS          = 8,            // bits per pixel
    parameter XB            = 12            // bits for image width
) (
    // system
    input   wire                    clk,
    input   wire                    rst,
    
    // configuration
    // (should be constant out of reset)
    input   wire    [XB-1:0]        cfg_width,      // width of raw image (0 based)
    input   wire                    cfg_first_r,    // first row has red pixels (otherwise blue)
    input   wire                    cfg_first_g,    // first pixel is green
    
    // pixels in from primary sequencer
    output  reg                     in_ready,
    input   wire                    in_valid,
    input   wire                    in_row_last,   // last pixel column of row
    input   wire                    in_frame_last, // last pixel column of frame
    input   wire    [BITS-1:0]      in_data,

    // control out to VNG pipeline
    output  wire                    vng_clk_en,
    output  wire    [3:0]           vng_st,
    output  wire                    vng_px_push,
    output  wire                    vng_px_masked,
    output  wire                    vng_px_last,
    output  wire                    vng_px_row_red,
    output  wire    [BITS-1:0]      vng_px_in,

    // feedback from VNG pipeline output
    input   wire                    out_almost_full,
    input   wire                    out_last
);

`include "dlsc_synthesis.vh"

// ** secondary sequencer **
// handles VNG state generation and column repetition

wire cfg_width_odd = (cfg_width[0] == 1'b0); // image width is an odd number of pixels

localparam  ST_RUN      = 1'd0,
            ST_FLUSH    = 1'd1;     // flush pipeline at end of frame

localparam  STX_CAP0    = 3'd0,     // capture/drive x = 0
            STX_CAP1    = 3'd1,     // capture/drive x = 1
            STX_REP0    = 3'd2,     // repeat 0
            STX_REP1    = 3'd3,     // repeat 1
            STX_NORM    = 3'd4,     // capture/drive x = [2,n]
            STX_REP2    = 3'd5,     // repeat n-1
            STX_REP3    = 3'd6,     // repeat n-0
            STX_PAD     = 3'd7;     // pad to change alignment of first green pixel

reg  [0:0]  st;             // overall state
reg  [2:0]  stx;            // column rep state
reg         sty;            // row state
reg  [3:0]  stv;            // VNG state
reg         in_ready_pre;

reg  [0:0]  next_st;
reg  [2:0]  next_stx;
reg         next_sty;
reg  [3:0]  next_stv;
reg         next_in_ready;

always @* begin
    next_st         = st;
    next_stx        = stx;
    next_sty        = sty;
    next_stv        = stv;
    next_in_ready   = in_ready_pre;
    
    next_stv        = (stv == 4'd11) ? 0 : (stv + 1);

    next_in_ready   = (stx == STX_CAP0 || stx == STX_CAP1 || stx == STX_NORM);

    if(stv == 4'd4 || stv == 4'd10) begin
        // update prior to inactive cycles (5 and 11)
        next_in_ready   = 1'b0;
        case(stx)
            STX_CAP0:   next_stx = STX_CAP1;
            STX_CAP1:   next_stx = STX_REP0;
            STX_REP0:   next_stx = STX_REP1;
            STX_REP1:   next_stx = STX_NORM;
            default:    next_stx = in_row_last ? STX_REP2 : STX_NORM;
            STX_REP2:   next_stx = STX_REP3;
            STX_REP3:   next_stx = (st == ST_FLUSH || !cfg_width_odd) ? STX_PAD : STX_CAP0;
            STX_PAD:    next_stx = (st == ST_FLUSH                  ) ? STX_PAD : STX_CAP0;
        endcase
        if(next_stx == STX_CAP0) begin
            // toggle Y at end of row
            next_sty        = !sty;
        end
        if(in_ready && in_valid && in_frame_last) begin
            next_st         = ST_FLUSH;
        end
    end
end

assign      in_ready        = !out_almost_full && in_ready_pre;
wire        update          = !out_almost_full && (!in_ready_pre || in_valid);

always @(posedge clk) begin
    if(rst || out_last) begin
        st              <= ST_RUN;
        stx             <= STX_CAP0;
        sty             <= 1'b0;
        stv             <= cfg_first_g ? 4'd6 : 4'd0;
        in_ready_pre    <= 1'b1;
    end else if(update) begin
        st              <= next_st;
        stx             <= next_stx;
        sty             <= next_sty;
        stv             <= next_stv;
        in_ready_pre    <= next_in_ready;
    end
end


// ** buffer columns **

`DLSC_LUTRAM reg [BITS-1:0] colbuf[11:0];

wire [BITS-1:0] colbuf_data;

assign colbuf_data = colbuf[stv];

always @(posedge clk) begin
    if(in_ready && in_valid) begin
        colbuf[stv]     <= in_data;
    end
end


// ** create control output **

reg             c0_clk_en;
reg  [3:0]      c0_st;
reg             c0_px_push;
reg             c0_px_masked;
reg             c0_px_last;
reg             c0_px_row_red;
reg  [BITS-1:0] c0_px_in;

always @* begin
    c0_clk_en       = update;
    c0_st           = stv;
    c0_px_push      = (stv != 4'd5 && stv != 4'd11);
    c0_px_masked    = !(stx == STX_REP0 || stx == STX_REP1 || stx == STX_NORM);
    c0_px_row_red   = sty ^ cfg_first_r;
    if(stx == STX_REP0 || stx == STX_REP1 || stx == STX_REP2 || stx == STX_REP3) begin
        c0_px_last      = 1'b0; 
        c0_px_in        = colbuf_data;
    end else begin
        c0_px_last      = in_frame_last;
        c0_px_in        = in_data;
    end
end


// ** buffer control output **

`DLSC_FANOUT_REG reg [3:0] c1_st;
`DLSC_FANOUT_REG reg       c1_clk_en;

reg             c1_px_push;
reg             c1_px_masked;
reg             c1_px_last;
reg             c1_px_row_red;
reg  [BITS-1:0] c1_px_in;

always @(posedge clk) begin
    c1_clk_en       <= 1'b0;
    if(c0_clk_en) begin
        c1_clk_en       <= 1'b1;
        c1_st           <= c0_st;
        c1_px_push      <= c0_px_push;
        c1_px_masked    <= c0_px_masked;
        c1_px_last      <= c0_px_last;
        c1_px_row_red   <= c0_px_row_red;
        c1_px_in        <= c0_px_in;
    end
end

`DLSC_FANOUT_REG reg c2_clk_en;
`DLSC_FANOUT_REG reg c2_px_push;

reg             c2_px_masked;
reg             c2_px_last;
reg             c2_px_row_red;
reg  [BITS-1:0] c2_px_in;

always @(posedge clk) begin
    c2_clk_en       <= 1'b0;
    if(c1_clk_en) begin
        c2_clk_en       <= 1'b1;
        c2_px_push      <= c1_px_push;
        c2_px_masked    <= c1_px_masked;
        c2_px_last      <= c1_px_last;
        c2_px_row_red   <= c1_px_row_red;
        c2_px_in        <= c1_px_in;
    end
end

assign vng_st           = c1_st;        // state needs an extra cycle to prop through ROMs
assign vng_clk_en       = c2_clk_en;
assign vng_px_push      = c2_px_push;
assign vng_px_masked    = c2_px_masked;
assign vng_px_last      = c2_px_last;
assign vng_px_row_red   = c2_px_row_red;
assign vng_px_in        = c2_px_in;

endmodule

