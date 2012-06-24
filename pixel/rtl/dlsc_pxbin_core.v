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
// Performs pixel binning to reduce image resolution. For Bayer inputs, will
// also convert to RGB when binning.

module dlsc_pxbin_core #(
    parameter BITS          = 8,            // bits per pixel
    parameter WIDTH         = 1024,         // maximum raw image width
    parameter XB            = 12,           // bits for image width
    parameter YB            = 12,           // bits for image height
    parameter BINB          = 3             // bits for selecting bin factor
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // configuration
    // (should be constant out of reset)
    input   wire    [XB-1:0]        cfg_width,      // width of raw image (0 based)
    input   wire    [YB-1:0]        cfg_height,     // height of raw image (0 based)
    input   wire    [BINB-1:0]      cfg_bin_x,      // horizontal bin factor (0 based)
    input   wire    [BINB-1:0]      cfg_bin_y,      // vertical bin factor (0 based)
    input   wire                    cfg_bayer,      // enable bayer-aware binning
    input   wire                    cfg_first_r,    // first row has red pixels (otherwise blue)
    input   wire                    cfg_first_g,    // first pixel is green
    
    // pixels in (raw)
    output  wire                    in_ready,
    input   wire                    in_valid,
    input   wire    [BITS-1:0]      in_data,

    // pixels out (color or raw; for raw, all channels are the same)
    input   wire                    out_ready,
    output  wire                    out_valid,
    output  wire    [BITS-1:0]      out_data_r,
    output  wire    [BITS-1:0]      out_data_g,
    output  wire    [BITS-1:0]      out_data_b
);

`include "dlsc_clog2.vh"

localparam  ADDR    = `dlsc_clog2(WIDTH);

localparam  MB      = BITS + 1*BINB;    // bits for row accumulators
localparam  AB      = BITS + 2*BINB;    // bits for column accumulators

localparam  DIVMAX  = 2*BINB;           // max shift amount for post-divide
localparam  DIVB    = `dlsc_clog2(DIVMAX);  // bits for post-divide selector

integer i;


// ** derived configuration **

/* verilator lint_off WIDTH */
reg  [DIVB-1:0] next_cfg_div_x;

always @* begin
    next_cfg_div_x  = {DIVB{1'bx}};
    for(i=0;i<(2**BINB);i=i+1) begin
        if(cfg_bin_x == i) begin
            next_cfg_div_x  = `dlsc_clog2(i+1);
        end
    end
end

reg  [DIVB-1:0] next_cfg_div_y;

always @* begin
    next_cfg_div_y  = {DIVB{1'bx}};
    for(i=0;i<(2**BINB);i=i+1) begin
        if(cfg_bin_y == i) begin
            next_cfg_div_y  = `dlsc_clog2(i+1);
        end
    end
end
/* verilator lint_on WIDTH */

reg  [DIVB-1:0] cfg_div_x;
reg  [DIVB-1:0] cfg_div_y;
reg  [DIVB  :0] cfg_div;
reg             cfg_bin_x_gt1;
reg             cfg_bin_y_gt1;

always @(posedge clk) begin
    if(!rst) begin
        cfg_div_x       <= next_cfg_div_x;
        cfg_div_y       <= next_cfg_div_y;
        cfg_div         <= cfg_div_x + cfg_div_y;
        cfg_bin_x_gt1   <= (cfg_bin_x != 0);
        cfg_bin_y_gt1   <= (cfg_bin_y != 0);
    end
end

reg  [DIVB  :0] cfg_div_rb;
reg  [DIVB  :0] cfg_div_g;

always @(posedge clk) begin
    if(!rst) begin
        casez({cfg_bayer,cfg_bin_y_gt1,cfg_bin_x_gt1})
            3'b0??:  begin cfg_div_rb <= cfg_div    ; cfg_div_g <= cfg_div    ; end // raw
            3'b111:  begin cfg_div_rb <= cfg_div - 2; cfg_div_g <= cfg_div - 1; end // bayer
            default: begin cfg_div_rb <= 0          ; cfg_div_g <= 0          ; end // bayer (with binning disabled on 1 or both axes)
        endcase
    end
end


// ** register input **

reg             c0_valid;
reg  [BITS-1:0] c0_data;

always @(posedge clk) begin
    c0_valid    <= in_ready && in_valid;
    if(in_valid) begin
        c0_data     <= in_data;
    end
end


// ** control **

reg  [XB-1:0]   x;
reg  [YB-1:0]   y;

wire            x_first     = (x == 0);
wire            y_first     = (y == 0);
wire            x_last      = (x == cfg_width);
wire            y_last      = (y == cfg_height);

reg  [BINB-1:0] bx;
reg  [BINB-1:0] by;

wire            bx_first    = (bx == 0) || (cfg_bayer && bx == 1);
wire            by_first    = (by == 0) || (cfg_bayer && by == 1);
wire            bx_last     = (bx == cfg_bin_x);
wire            by_last     = (by == cfg_bin_y);

reg  [XB-1:0]   next_x;
reg  [YB-1:0]   next_y;

reg  [BINB-1:0] next_bx;
reg  [BINB-1:0] next_by;

always @* begin
    next_x      = x;
    next_y      = y;
    next_bx     = bx;
    next_by     = by;

    if(c0_valid) begin
        // update x bin
        next_bx     = bx + 1;
        if(bx_last) begin
            next_bx     = 0;
        end
        // update pixel counters
        next_x      = x + 1;
        if(x_last) begin
            // reset x bin; update y bin
            next_bx     = 0;
            next_by     = by + 1;
            if(by_last) begin
                next_by     = 0;
            end
            // reset x pixel; update y pixel
            next_x      = 0;
            next_y      = y + 1;
            if(y_last) begin
                next_y      = 0;
                next_by     = 0;
            end
        end
    end
end

always @(posedge clk) begin
    if(rst) begin
        x       <= 0;
        y       <= 0;
        bx      <= 0;
        by      <= 0;
    end else begin
        x       <= next_x;
        y       <= next_y;
        bx      <= next_bx;
        by      <= next_by;
    end
end


// ** control delays **

// In raw mode, force _x and _y to always be 0, so acc00 is always used
wire            c0_y            = cfg_bayer ? y[0] : 1'b0;
wire            c0_x            = cfg_bayer ? x[0] : 1'b0;

wire            c0_en           = c0_valid && bx_last && by_last;   // push output on last bin

wire            c2_y;
wire            c2_y_first;
wire            c2_by_first;
wire [BITS-1:0] c2_data;

dlsc_pipedelay #(
    .DATA       ( 3+BITS ),
    .DELAY      ( 2-0 )
) dlsc_pipedelay_c0c2 (
    .clk        ( clk ),
    .in_data    ( {c0_y,   y_first,   by_first,c0_data} ),
    .out_data   ( {c2_y,c2_y_first,c2_by_first,c2_data} )
);

wire            c3_valid;
wire            c3_x;
wire            c3_x_first;
wire            c3_bx_first;
wire            c3_wr_en;
wire [ADDR-1:0] c3_wr_addr;

dlsc_pipedelay #(
    .DATA       ( 5+ADDR ),
    .DELAY      ( 3-0 )
) dlsc_pipedelay_c0c3 (
    .clk        ( clk ),
    .in_data    ( {c0_valid,c0_x,   x_first,   bx_first,c0_valid,x[ADDR-1:0]} ),
    .out_data   ( {c3_valid,c3_x,c3_x_first,c3_bx_first,c3_wr_en,c3_wr_addr } )
);

wire            c4_y;

dlsc_pipedelay #(
    .DATA       ( 1 ),
    .DELAY      ( 4-2 )
) dlsc_pipedelay_c2c4 (
    .clk        ( clk ),
    .in_data    ( c2_y ),
    .out_data   ( c4_y )
);

wire            c6_en;

dlsc_pipedelay #(
    .DATA       ( 1 ),
    .DELAY      ( 6-0 )
) dlsc_pipedelay_c0c6 (
    .clk        ( clk ),
    .in_data    ( c0_en ),
    .out_data   ( c6_en )
);
    

// ** accumulate rows **

wire [MB-1:0]   c2_buf0;
wire [MB-1:0]   c2_buf1;

reg  [MB-1:0]   c3_buf0;
reg  [MB-1:0]   c3_buf1;

wire [MB-1:0]   c2_buf0_masked  = (c2_y_first || (c2_by_first && c2_y == 1'b0)) ? 0 : c2_buf0;
wire [MB-1:0]   c2_buf1_masked  = (c2_y_first || (c2_by_first && c2_y == 1'b1)) ? 0 : c2_buf1;

wire [MB-1:0]   c2_data0_masked = (c2_y == 1'b0) ? {{BINB{1'b0}}, c2_data} : 0;
wire [MB-1:0]   c2_data1_masked = (c2_y == 1'b1) ? {{BINB{1'b0}}, c2_data} : 0;

always @(posedge clk) begin
    c3_buf0     <= c2_buf0_masked + c2_data0_masked;
    c3_buf1     <= c2_buf1_masked + c2_data1_masked;
end


// ** accumulate columns **

reg  [AB-1:0]   c4_acc00;
reg  [AB-1:0]   c4_acc01;
reg  [AB-1:0]   c4_acc10;
reg  [AB-1:0]   c4_acc11;

always @(posedge clk) begin
    if(c3_valid) begin
        c4_acc00    <= ((c3_x_first || (c3_bx_first && c3_x == 1'b0)) ? 0 : c4_acc00) + ((c3_x == 1'b0) ? {{BINB{1'b0}},c3_buf0} : 0);
        c4_acc01    <= ((c3_x_first || (c3_bx_first && c3_x == 1'b1)) ? 0 : c4_acc01) + ((c3_x == 1'b1) ? {{BINB{1'b0}},c3_buf0} : 0);
        c4_acc10    <= ((c3_x_first || (c3_bx_first && c3_x == 1'b0)) ? 0 : c4_acc10) + ((c3_x == 1'b0) ? {{BINB{1'b0}},c3_buf1} : 0);
        c4_acc11    <= ((c3_x_first || (c3_bx_first && c3_x == 1'b1)) ? 0 : c4_acc11) + ((c3_x == 1'b1) ? {{BINB{1'b0}},c3_buf1} : 0);
    end
end


// ** select outputs **

// In raw mode, force _x and _y to always be 0, so acc00 is always used
// 
// Bayer, biny = 1
//     case({first_g,first_r})
//         00: blue <= acc00; green <= (y==0) ? acc01 : acc10; red  <= acc11;
//         01: red  <= acc00; green <= (y==0) ? acc01 : acc10; blue <= acc11;
//         10: blue <= acc01; green <= (y==0) ? acc00 : acc11; red  <= acc10;
//         11: red  <= acc01; green <= (y==0) ? acc00 : acc11; blue <= acc10;
//     endcase
// 
// Bayer, biny > 1
//     case({first_g,first_r})
//         00: blue <= acc00; green <= acc01 + acc10; red  <= acc11;
//         01: red  <= acc00; green <= acc01 + acc10; blue <= acc11;
//         10: blue <= acc01; green <= acc00 + acc11; red  <= acc10;
//         11: red  <= acc01; green <= acc00 + acc11; blue <= acc10;
//     endcase

reg  [AB-1:0]   c4_g_a;
reg  [AB-1:0]   c4_g_b;

always @* begin
    case({cfg_bayer,cfg_first_g})
        2'b10:   begin c4_g_a = c4_acc01; c4_g_b = c4_acc10; end  // xGxG
        2'b11:   begin c4_g_a = c4_acc00; c4_g_b = c4_acc11; end  // GxGx
        default: begin c4_g_a = c4_acc00; c4_g_b = c4_acc11; end  // raw
    endcase
end

reg  [AB-1:0]   c5_r;
reg  [AB-1:0]   c5_g;
reg  [AB-1:0]   c5_b;

always @(posedge clk) begin
    case({cfg_bayer,cfg_first_g,cfg_first_r})
        3'b100:  begin c5_r <= c4_acc11; c5_b <= c4_acc00; end  // BGBG
        3'b101:  begin c5_r <= c4_acc00; c5_b <= c4_acc11; end  // RGRG
        3'b110:  begin c5_r <= c4_acc10; c5_b <= c4_acc01; end  // GBGB
        3'b111:  begin c5_r <= c4_acc01; c5_b <= c4_acc10; end  // GRGR
        default: begin c5_r <= c4_acc00; c5_b <= c4_acc00; end  // raw
    endcase
    c5_g <= ((             (cfg_bin_y_gt1 || c4_y == 1'b0)) ? c4_g_a : 0) +
            ((cfg_bayer && (cfg_bin_y_gt1 || c4_y == 1'b1)) ? c4_g_b : 0);
end


// ** normalize **

reg  [BITS-1:0] next_c6_r;
reg  [BITS-1:0] next_c6_g;
reg  [BITS-1:0] next_c6_b;

always @* begin
    next_c6_r   = {BITS{1'bx}};
    next_c6_g   = {BITS{1'bx}};
    next_c6_b   = {BITS{1'bx}};

    for(i=0;i<=DIVMAX;i=i+1) begin
        /* verilator lint_off WIDTH */
        if(i == cfg_div_rb) next_c6_r = c5_r[ i +: BITS ];
        if(i == cfg_div_g ) next_c6_g = c5_g[ i +: BITS ];
        if(i == cfg_div_rb) next_c6_b = c5_b[ i +: BITS ];
        /* verilator lint_on WIDTH */
    end
end

reg  [BITS-1:0] c6_r;
reg  [BITS-1:0] c6_g;
reg  [BITS-1:0] c6_b;

always @(posedge clk) begin
    c6_r    <= next_c6_r;
    c6_g    <= next_c6_g;
    c6_b    <= next_c6_b;
end


// ** row accumulator RAM **

dlsc_ram_dp #(
    .DATA           ( 2*MB ),
    .ADDR           ( ADDR ),
    .DEPTH          ( WIDTH ),
    .PIPELINE_WR    ( 1 ),
    .PIPELINE_RD    ( 2 )
) dlsc_ram_dp (
    .write_clk      ( clk ),
    .write_en       ( c3_wr_en ),
    .write_addr     ( c3_wr_addr ),
    .write_data     ( {c3_buf1,c3_buf0} ),
    .read_clk       ( clk ),
    .read_en        ( c0_valid ),
    .read_addr      ( x[ADDR-1:0] ),
    .read_data      ( {c2_buf1,c2_buf0} )
);


// ** output FIFO **

wire fifo_almost_full;
assign in_ready = !fifo_almost_full;

dlsc_fifo_rvho #(
    .DEPTH          ( 16 ),
    .DATA           ( 3*BITS ),
    .ALMOST_FULL    ( 8 ),
    .FULL_IN_RESET  ( 1 )
) dlsc_fifo_rvho (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( c6_en ),
    .wr_data        ( {c6_r,c6_g,c6_b} ),
    .wr_full        (  ),
    .wr_almost_full ( fifo_almost_full ),
    .wr_free        (  ),
    .rd_ready       ( out_ready ),
    .rd_valid       ( out_valid ),
    .rd_data        ( {out_data_r,out_data_g,out_data_b} ),
    .rd_almost_empty (  )
);

endmodule

