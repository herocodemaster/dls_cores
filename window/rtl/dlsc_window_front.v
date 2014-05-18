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
// Generates a window of pixels from an incoming pixel stream. Vertical windowing
// is accomplished by outputting an entire column of pixels covering the window.
// Horizontal windowing requires that downstream modules accumulate a window;
// this module will drive additional columns to fill the specified horizontal
// window.
//
// Multiple modes are provided for handling edge cases (via EDGE_MODE parameter):
//  NONE:   Output is only produced once outside of an edge region. Output
//          is reduced in width and height.
//  FILL:   Pixels outside of the input are filled with a constant value
//          (supplied via the cfg_fill input).
//  REPEAT: Pixels outside of the input are filled with their nearest valid
//          neighbor.
//  BAYER:  Pixels outside of the input are filled with their nearest valid
//          neighbor of the same color.
//
// This module is intended to be paired with a dlsc_window_back module at the
// end of the pipeline segment that this module is feeding.
//

module dlsc_window_front #(
    parameter CYCLES        = 1,            // cycles per pixel
    parameter WINX          = 3,            // horizontal window size (odd; >= 1)
    parameter WINY          = WINX,         // vertical window size (odd; >= 1)
    parameter MAXX          = 1024,         // max image width
    parameter XB            = 10,           // bits for horizontal resolution
    parameter YB            = 10,           // bits for vertical resolution
    parameter BITS          = 8,            // bits per pixel
    parameter EDGE_MODE     = "REPEAT"      // NONE, FILL, REPEAT, BAYER
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // status
    output  reg                     done,       // entire frame has been consumed at input

    // config
    // must be static out of reset
    input   wire    [XB-1:0]        cfg_x,      // image width ; 0 based
    input   wire    [YB-1:0]        cfg_y,      // image height; 0 based
    input   wire    [BITS-1:0]      cfg_fill,   // fill value for EDGE_MODE = "FILL"

    // input
    output  wire                    in_ready,
    input   wire                    in_valid,
    input   wire                    in_unmask,
    input   wire    [BITS-1:0]      in_data,

    // flow control to dlsc_window_back
    // latency from fc_okay to fc_valid is 3 cycles
    input   wire                    fc_okay,
    output  reg                     fc_valid,
    output  reg                     fc_unmask,
    output  reg                     fc_last,    // last pixel in frame
    output  reg                     fc_last_x,  // last pixel in row

    // output to pipeline
    // latency from input to output is ~5 cycles
    output  reg                     out_valid,
    output  reg                     out_unmask,
    output  reg                     out_last,   // last pixel in frame
    output  reg                     out_last_x, // last pixel in row
    output  wire    [WINY*BITS-1:0] out_data
);

`include "dlsc_util.vh"
`include "dlsc_synthesis.vh"

`dlsc_static_assert_gte(WINX,1)
`dlsc_static_assert_gte(WINY,1)
`dlsc_static_assert_eq(WINX%2,1)
`dlsc_static_assert_eq(WINY%2,1)

/* verilator lint_off WIDTH */
localparam EM_FILL      = (EDGE_MODE == "FILL")     || (EDGE_MODE == 1);
localparam EM_REPEAT    = (EDGE_MODE == "REPEAT")   || (EDGE_MODE == 2);
localparam EM_BAYER     = (EDGE_MODE == "BAYER")    || (EDGE_MODE == 3);
localparam EM_NONE      = !(EM_FILL || EM_REPEAT || EM_BAYER);
/* verilator lint_on WIDTH */

// ** input decoupling **
// TODO: this needs more work (especially wrt not consuming data after last)

//wire            in_full;
//wire            in_push     = !in_full && in_valid;
//assign          in_ready    = !in_full;
//
//reg             c0_pop;
//wire            c0_empty;
//wire            c0_unmask;
//wire [BITS-1:0] c0_data;
//
//dlsc_fifo #(
//    .DEPTH          ( (CYCLES>1) ? 1 : 2 ),
//    .DATA           ( 1+BITS ),
//    .FULL_IN_RESET  ( 1 )
//) dlsc_fifo_in (
//    .clk            ( clk ),
//    .rst            ( rst ),
//    .wr_push        ( in_push ),
//    .wr_data        ( { in_unmask, in_data } ),
//    .wr_full        ( in_full ),
//    .wr_almost_full (  ),
//    .wr_free        (  ),
//    .rd_pop         ( c0_pop ),
//    .rd_data        ( { c0_unmask, c0_data } ),
//    .rd_empty       ( c0_empty ),
//    .rd_almost_empty (  ),
//    .rd_count       (  )
//);

reg             c0_pop;
assign          in_ready    = c0_pop;
wire            c0_empty    = !in_valid;
wire            c0_unmask   = in_unmask;
wire [BITS-1:0] c0_data     = in_data;

// ** flow control **

wire            c0_en_fc;

dlsc_window_front_control_flow #(
    .CYCLES         ( CYCLES )
) dlsc_window_front_control_flow (
    .clk            ( clk ),
    .rst            ( rst ),
    .fc_okay        ( fc_okay ),
    .c0_en          ( c0_en_fc )
);

wire            c0_en_y_pre;
wire            c0_in_en_x;
wire            c0_in_en_y;
reg             c0_en;
reg             c0_en_y;

always @* begin
    c0_pop  = 1'b0;
    c0_en   = 1'b0;
    c0_en_y = 1'b0;
    if(c0_en_fc) begin
        if(!(c0_in_en_x && c0_in_en_y)) begin
            // generated internally
            c0_en   = 1'b1;
            c0_en_y = c0_en_y_pre;
        end else if(!c0_empty && c0_unmask) begin
            // coming from input
            c0_pop  = 1'b1;
            c0_en   = 1'b1;
            c0_en_y = c0_en_y_pre;
        end
    end
    if(!c0_empty && !c0_unmask) begin
        // eat masked input pixels
        c0_pop  = 1'b1;
    end
end

// ** X control **

wire            c1_out_en_x;
wire            c1_out_unmask_x;
wire            c1_out_last_x;
wire            c1_fill;
wire            c1_rd_en;
wire            c1_wr_en;
wire [XB-1:0]   c1_addr;

dlsc_window_front_control_x #(
    .WINX           ( WINX ),
    .XB             ( XB ),
    .EM_FILL        ( EM_FILL ),
    .EM_REPEAT      ( EM_REPEAT ),
    .EM_BAYER       ( EM_BAYER ),
    .EM_NONE        ( EM_NONE )
) dlsc_window_front_control_x (
    .clk            ( clk ),
    .rst            ( rst ),
    .cfg_x          ( cfg_x ),
    .c0_en          ( c0_en ),
    .c0_en_y        ( c0_en_y_pre ),
    .c0_in_en       ( c0_in_en_x ),
    .c1_out_en      ( c1_out_en_x ),
    .c1_out_unmask  ( c1_out_unmask_x ),
    .c1_out_last    ( c1_out_last_x ),
    .c1_fill        ( c1_fill ),
    .c1_rd_en       ( c1_rd_en ),
    .c1_wr_en       ( c1_wr_en ),
    .c1_addr        ( c1_addr )
);

// ** Y control **

wire            c1_out_en_y;
wire            c1_out_unmask_y;
wire            c1_out_last_y;
wire            c1_prime;
wire            c1_post;

dlsc_window_front_control_y #(
    .WINY           ( WINY ),
    .YB             ( YB ),
    .EM_FILL        ( EM_FILL ),
    .EM_REPEAT      ( EM_REPEAT ),
    .EM_BAYER       ( EM_BAYER ),
    .EM_NONE        ( EM_NONE )
) dlsc_window_front_control_y (
    .clk            ( clk ),
    .rst            ( rst ),
    .cfg_y          ( cfg_y ),
    .c0_en          ( c0_en_y ),
    .c0_in_en       ( c0_in_en_y ),
    .c1_out_en      ( c1_out_en_y ),
    .c1_out_unmask  ( c1_out_unmask_y ),
    .c1_out_last    ( c1_out_last_y ),
    .c1_prime       ( c1_prime ),
    .c1_post        ( c1_post )
);

// ** derived control **

reg c1_en;
reg c1_in_en;
reg c2_in_en;
reg c2_out_en;
reg c2_out_unmask;
reg c2_out_last;
reg c2_out_last_x;
reg c2_wr_en;
reg c2_prime;
reg c2_post;

wire next_c2_out_en     = c1_en && c1_out_en_x && c1_out_en_y;
wire next_c2_out_unmask = c1_en && c1_out_unmask_x && c1_out_unmask_y;
wire next_c2_out_last   = c1_out_last_x && c1_out_last_y;
wire next_c2_out_last_x = c1_out_last_x;

always @(posedge clk) begin
    c1_en           <= c0_en;
    c1_in_en        <= c0_in_en_x && c0_in_en_y;
    c2_in_en        <= c1_en && c1_in_en;
    c2_out_en       <= next_c2_out_en;
    c2_out_unmask   <= next_c2_out_unmask;
    c2_out_last     <= next_c2_out_last;
    c2_out_last_x   <= next_c2_out_last_x;
    c2_wr_en        <= c1_en && c1_wr_en;
    c2_prime        <= c1_prime || c1_fill;
    c2_post         <= c1_post  || c1_fill;
end

                 reg c3_out_en;
                 reg c3_out_unmask;
                 reg c3_out_last;
                 reg c3_out_last_x;
`DLSC_FANOUT_REG reg c3_prime;
`DLSC_FANOUT_REG reg c3_post;

always @(posedge clk) begin
    c3_out_en       <= c2_out_en;
    c3_out_unmask   <= c2_out_unmask;
    c3_out_last     <= c2_out_last;
    c3_out_last_x   <= c2_out_last_x;
    c3_prime        <= c2_prime;
    c3_post         <= c2_post;
end

// ** input repeating **

                reg  [BITS-1:0] c1_data;
                reg  [BITS-1:0] c2_data;
`DLSC_PIPE_REG  reg  [BITS-1:0] c3_data;

always @(posedge clk) begin
    c1_data     <= c0_data;
    c2_data     <= c1_data;
    if(c2_in_en) begin
        c3_data     <= c2_data;
    end
end

// ** memory **

dlsc_window_front_ram #(
    .BITS           ( BITS ),
    .WINX           ( WINX ),
    .WINY           ( WINY ),
    .MAXX           ( MAXX ),
    .XB             ( XB ),
    .EM_FILL        ( EM_FILL ),
    .EM_REPEAT      ( EM_REPEAT ),
    .EM_BAYER       ( EM_BAYER ),
    .EM_NONE        ( EM_NONE )
) dlsc_window_front_ram (
    .clk            ( clk ),
    .cfg_fill       ( cfg_fill ),
    .c1_addr        ( c1_addr ),
    .c1_rd_en       ( c1_rd_en ),
    .c2_wr_en       ( c2_wr_en ),
    .c3_prime       ( c3_prime ),
    .c3_post        ( c3_post ),
    .c3_in_data     ( c3_data ),
    .c4_out_data    ( out_data )
);

// ** output **

always @(posedge clk) begin
    if(rst) begin
        done        <= 1'b0;
        fc_valid    <= 1'b0;
        fc_unmask   <= 1'b0;
        out_valid   <= 1'b0;
        out_unmask  <= 1'b0;
    end else begin
        done        <= done || (c3_out_en && c3_out_last);
        fc_valid    <= next_c2_out_en;
        fc_unmask   <= next_c2_out_unmask;
        out_valid   <= c3_out_en;
        out_unmask  <= c3_out_unmask;
    end
end

always @(posedge clk) begin
    fc_last     <= next_c2_out_last;
    fc_last_x   <= next_c2_out_last_x;
    out_last    <= c3_out_last;
    out_last_x  <= c3_out_last_x;
end

endmodule

