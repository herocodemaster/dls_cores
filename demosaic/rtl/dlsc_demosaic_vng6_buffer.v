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
// Input row buffering for VNG core.

module dlsc_demosaic_vng6_buffer #(
    parameter BITS          = 8,            // bits per pixel
    parameter XB            = 12,           // bits for image width
    parameter YB            = 12            // bits for image height
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // configuration
    // (should be constant out of reset)
    input   wire    [XB-1:0]        cfg_width,      // width of raw image (0 based)
    input   wire    [YB-1:0]        cfg_height,     // height of raw image (0 based)
    
    // pixels in (raw)
    output  wire                    in_ready,
    input   wire                    in_valid,
    input   wire    [BITS-1:0]      in_data,

    // pixels out to secondary sequencer
    input   wire                    out_ready,
    output  reg                     out_valid,
    output  reg                     out_row_last,   // last pixel column of row
    output  reg                     out_frame_last, // last pixel column of frame
    output  wire    [BITS-1:0]      out_data
);

localparam ADDR = XB+2;

// ** primary sequencer **
// handles buffer addressing and row repetition

localparam  STY_NEG2    =   3'd0,
            STY_NEG1    =   3'd1,
            STY_NORM    =   3'd2,
            STY_POS1    =   3'd3,
            STY_POS2    =   3'd4;

reg  [2:0]      sty;
reg  [2:0]      str;

wire            sty_neg     = (sty == STY_NEG2 || sty == STY_NEG1);
wire            sty_last    = (sty == STY_POS2);
wire            str_last    = (str == 3'd4);

reg  [2:0]      row_base;
reg  [2:0]      row;
reg  [XB-1:0]   x;
reg  [YB-1:0]   y;

wire            x_last      = (x == cfg_width);
wire            y_last      = (y == cfg_height);

reg  [2:0]      next_sty;
reg  [2:0]      next_str;
reg  [2:0]      next_row_base;
reg  [2:0]      next_row;
reg  [XB-1:0]   next_x;
reg  [YB-1:0]   next_y;

reg             x_inc;
reg             x_rst;

always @* begin
    next_sty        = sty;
    next_str        = str + 1;

    x_inc           = 1'b0;
    x_rst           = 1'b0;
    
    next_y          = y;

    next_row_base   = row_base;
    next_row        = row + 1;
    case(sty)
        STY_NEG2: next_row = (str == 3'd1) ? (row - 1) : (row + 1); // 0, 1, 0, 1, 2
        STY_NEG1: next_row = (str == 3'd0) ? (row - 1) : (row + 1); // 1, 0, 1, 2, 3
        default:  next_row =                             (row + 1); // 0, 1, 2, 3, 4
        STY_POS1: next_row = (str == 3'd3) ? (row - 1) : (row + 1); // 0, 1, 2, 3, 2
        STY_POS2: next_row = (str == 3'd2) ? (row - 1) : (row + 1); // 0, 1, 2, 1, 2
    endcase

    if(str_last) begin
        next_str        = 3'd0;

        // ** increment X **
        x_inc           = 1'b1;

        if(x_last) begin
            // ** increment Y **
            x_rst           = 1'b1;
            next_y          = y + 1;

            if(!sty_neg) begin
                next_row_base   = row_base + 1;
            end
        
            case(sty)
                STY_NEG2: next_sty = STY_NEG1;
                STY_NEG1: next_sty = STY_NORM;
                default:  next_sty = y_last ? STY_POS1 : STY_NORM;
                STY_POS1: next_sty = STY_POS2;
                STY_POS2: next_sty = STY_NEG2;
            endcase

            if(sty_last) begin
                // ** end frame **
                next_y          = 2;
            end
        end
        
        next_row        = (next_sty == STY_NEG1) ? (next_row_base + 1) : (next_row_base);
    end

    next_x          = x_rst ? 0 : (x_inc ? (x + 1) : x);
end

wire            rd_en;

always @(posedge clk) begin
    if(rst) begin
        sty         <= STY_NEG2;
        str         <= 0;
        row_base    <= 0;
        row         <= 0;
        x           <= 0;
        y           <= 2;   // start at 2, so we detect end of frame 2 rows before it actually occurs (so we can repeat those rows correctly)
    end else if(rd_en) begin
        sty         <= next_sty;
        str         <= next_str;
        row_base    <= next_row_base;
        row         <= next_row;
        x           <= next_x;
        y           <= next_y;
    end
end


// ** reader **

reg  [2:0]      wr_row;
reg  [XB-1:0]   wr_x;
wire [ADDR:0]   wr_addr         = {wr_row,wr_x};

wire [ADDR:0]   rd_addr         = {row,x};

wire            rd_okay         = (wr_addr != rd_addr) && ((row-1) != wr_row);

assign          rd_en           = rd_okay && (!out_valid || out_ready);
wire            rd_row_last     = x_last; // && str_last;   // must assert for entire column of last pixels
wire            rd_frame_last   = rd_row_last && sty_last;

// compute next base address so writer knows when to stop
reg  [ADDR:0]   rd_addr_base;
always @(posedge clk) begin
    if(rst) begin
        rd_addr_base    <= 0;
    end else begin
        if(!sty_neg) begin
            rd_addr_base[XB+:3]     <= row_base;
            rd_addr_base[XB-1:0]    <= x + 1;
            if(x_last) begin
                rd_addr_base[XB+:3]     <= row_base + 1;
                rd_addr_base[XB-1:0]    <= 0;
            end
        end
    end
end


// ** writer **

wire            wr_okay         = ({~wr_addr[ADDR],wr_addr[ADDR-1:0]} != rd_addr_base);

wire            wr_fifo_full;
assign          in_ready        = !wr_fifo_full;

wire            wr_fifo_empty;
wire            wr_en           = wr_okay && !wr_fifo_empty;

always @(posedge clk) begin
    if(rst) begin
        wr_row          <= 0;
        wr_x            <= 0;
    end else if(wr_en) begin
        wr_x            <= wr_x + 1;
        if(wr_x == cfg_width) begin
            wr_x            <= 0;
            wr_row          <= wr_row + 1;
        end
    end
end

wire [BITS-1:0] wr_data;

dlsc_fifo #(
    .DEPTH          ( 16 ),
    .DATA           ( BITS )
) dlsc_fifo_in (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( in_ready && in_valid ),
    .wr_data        ( in_data ),
    .wr_full        ( wr_fifo_full ),
    .wr_almost_full (  ),
    .wr_free        (  ),
    .rd_pop         ( wr_en ),
    .rd_data        ( wr_data ),
    .rd_empty       ( wr_fifo_empty ),
    .rd_almost_empty (  ),
    .rd_count       (  )
);


// ** buffer RAM **

dlsc_ram_dp #(
    .DATA           ( BITS ),
    .ADDR           ( ADDR ),
    .PIPELINE_WR    ( 0 ),
    .PIPELINE_RD    ( 1 )
) dlsc_ram_dp (
    .write_clk      ( clk ),
    .write_en       ( wr_en ),
    .write_addr     ( wr_addr[ADDR-1:0] ),
    .write_data     ( wr_data ),
    .read_clk       ( clk ),
    .read_en        ( rd_en ),
    .read_addr      ( rd_addr[ADDR-1:0] ),
    .read_data      ( out_data )
);

always @(posedge clk) begin
    if(rst) begin
        out_valid       <= 1'b0;
        out_row_last    <= 1'b0;
        out_frame_last  <= 1'b0;
    end else begin
        if(out_ready) begin
            out_valid       <= 1'b0;
            out_row_last    <= 1'b0;
            out_frame_last  <= 1'b0;
        end
        if(rd_en) begin
            out_valid       <= 1'b1;
            out_row_last    <= rd_row_last;
            out_frame_last  <= rd_frame_last;
        end
    end
end


endmodule

