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
// Performs the same filtering as OpenCV's prefilterXSobel function
// (specifically: the non-SSE version present in OpenCV 2.2.0). For strict
// compatibility with OpenCV's implementation, set OUT_CLAMP to 2*ftzero.
//
// The module must buffer 1 whole input row before it starts producing output
// rows. Once primed, 1 output pixel is produced for each input pixel (with a
// pipeline delay of < 20 cycles).
//
// On the final output row for a frame (which is generated using purely buffered
// data), the module temporarily stops consuming input data.
//
// Assuming no input or output throttling, the module requires (IMG_WIDTH + 1)
// cycles to process each row, and ((IMG_HEIGHT + 1) * (IMG_WIDTH + 1)) cycles
// to process an entire frame.

module dlsc_xsobel_core #(
    parameter IN_DATA       = 8,                // bit width of input pixels
    parameter OUT_DATA      = 4,                // bit width of output pixels (OUT_DATA <= IN_DATA)
    parameter OUT_CLAMP     = (2**OUT_DATA)-1,  // maximum output value (defaults to full range of OUT_DATA)
    parameter IMG_WIDTH     = 137,              // width of filtered image
    parameter IMG_HEIGHT    = 52                // height of filtered image
) (
    // system
    input   wire                        clk,                // clock; all inputs synchronous to this; all outputs registered by this
    input   wire                        rst,                // synchronous reset

    // input
    output  wire                        in_ready,           // ready/valid handshake for input pixels
    input   wire                        in_valid,           // ""
    input   wire    [IN_DATA-1:0]       in_px,              // input pixel

    // output
    input   wire                        out_ready,          // ready/valid handshake for output pixels
    output  reg                         out_valid,          // ""
    output  reg     [OUT_DATA-1:0]      out_px              // filtered output pixel
);

`include "dlsc_clog2.vh"

localparam XBITS = `dlsc_clog2(IMG_WIDTH);
localparam YBITS = `dlsc_clog2(IMG_HEIGHT);

localparam OUT_OFFSET = OUT_CLAMP/2;

/* verilator lint_off WIDTH */
wire [IN_DATA+3:0]  out_offset  = OUT_OFFSET;
wire [OUT_DATA-1:0] out_clamp   = OUT_CLAMP;
/* verilator lint_on WIDTH */


`ifdef SIMULATION
/* verilator coverage_off */
// check configuration parameters
initial begin
    if(OUT_DATA > IN_DATA) begin
        $display("[%m] *** ERROR *** IN_DATA (%0d) must be >= OUT_DATA (%0d)", IN_DATA, OUT_DATA);
    end
    if(OUT_CLAMP >= (2**OUT_DATA)) begin
        $display("[%m] *** ERROR *** OUT_CLAMP (%0d) must be < (2**OUT_DATA) (%0d)", OUT_CLAMP, (2**OUT_DATA));
    end
end
/* verilator coverage_on */
`endif


// ** decouple input **
wire                    c0_ready;
wire                    c0_valid;
wire    [IN_DATA-1:0]   c0_px;

dlsc_rvh_decoupler #(
    .WIDTH      ( IN_DATA )
) dlsc_rvh_decoupler_inst (
    .clk        ( clk ),
    .rst        ( rst ),
    .in_en      ( 1'b1 ),
    .in_ready   ( in_ready ),
    .in_valid   ( in_valid ),
    .in_data    ( in_px ),
    .out_en     ( 1'b1 ),
    .out_ready  ( c0_ready ),
    .out_valid  ( c0_valid ),
    .out_data   ( c0_px )
);


// ** control **

reg [XBITS-1:0] x;
reg             x_pre;      // x == 0
reg             x_first;    // x == 1
reg             x_last;     // x == IMG_WIDTH (effectively; actual register may have harmlessly wrapped)

reg [YBITS-1:0] y;
reg             y_pre;      // y == 0
reg             y_first;    // y == 1
reg             y_last;     // y == IMG_HEIGHT (effectively; actual register may have harmlessly wrapped)

wire            en;

wire            fifo_out_busy;

assign c0_ready = !fifo_out_busy && !x_last && !y_last;

assign en       = !fifo_out_busy && (c0_valid || x_last || y_last);

/* verilator lint_off WIDTH */
always @(posedge clk) begin
    if(rst) begin

        x           <= 0;
        x_pre       <= 1'b1;
        x_first     <= 1'b0;
        x_last      <= 1'b0;

        y           <= 0;
        y_pre       <= 1'b1;
        y_first     <= 1'b0;
        y_last      <= 1'b0;

    end else if(en) begin

        x           <= x_last ? 0 : (x + 1);
        x_pre       <= x_last;
        x_first     <= x_pre;
        x_last      <= (x == IMG_WIDTH-1);

        if(x_last) begin
            y           <= y_last ? 0 : (y + 1);
            y_pre       <= y_last;
            y_first     <= y_pre;
            y_last      <= (y == IMG_HEIGHT-1);
        end

    end
end
/* verilator lint_on WIDTH */

// create enables
reg             c1_wr;
reg             c1_rd;
reg             c1_en;

always @(posedge clk) begin
    if(rst) begin
        c1_wr       <= 1'b0;
        c1_rd       <= 1'b0;
        c1_en       <= 1'b0;
    end else begin
        // don't write on last row, nor on last column
        c1_wr       <= en && !y_last && !x_last;

        // don't read on first row, nor on last column
        c1_rd       <= en && !y_pre && !x_last;

        // don't output pixel on first row, nor on first column
        c1_en       <= en && !y_pre && !x_pre;
    end
end

// create other control signals
reg [XBITS-1:0] c1_x;
reg             c1_zero;

always @(posedge clk) begin
    c1_x        <= x;
    c1_zero     <= x_first || x_last;   // output is OUT_OFFSET for first and last pixel in column
end


// ** delays **

wire [IN_DATA-1:0] c3_px;
dlsc_pipedelay #(
    .DATA           ( IN_DATA ),
    .DELAY          ( 3 - 0 )
) dlsc_pipedelay_inst_c3_px (
    .clk            ( clk ),
    .in_data        ( c0_px ),
    .out_data       ( c3_px )
);

wire                c3_y_first;
wire                c3_y_last;
dlsc_pipedelay #(
    .DATA           ( 2 ),
    .DELAY          ( 3 - 0 )
) dlsc_pipedelay_inst_c3_y_firstlast (
    .clk            ( clk ),
    .in_data        ( {    y_first,    y_last } ),
    .out_data       ( { c3_y_first, c3_y_last } )
);

wire                c3_rd;
dlsc_pipedelay #(
    .DATA           ( 1 ),
    .DELAY          ( 3 - 1 )
) dlsc_pipedelay_inst_c3_rd (
    .clk            ( clk ),
    .in_data        ( c1_rd ),
    .out_data       ( c3_rd )
);

wire                c4_zero;
dlsc_pipedelay #(
    .DATA           ( 1 ),
    .DELAY          ( 4 - 1 )
) dlsc_pipedelay_inst_c4_zero (
    .clk            ( clk ),
    .in_data        ( c1_zero ),
    .out_data       ( c4_zero )
);

wire                c9_en;
dlsc_pipedelay_rst #(
    .DATA           ( 1 ),
    .DELAY          ( 9 - 1 ),
    .RESET          ( 1'b0 )
) dlsc_pipedelay_rst_inst_c9_en (
    .clk            ( clk ),
    .rst            ( rst ),
    .in_data        ( c1_en ),
    .out_data       ( c9_en )
);


// ** buffering **
wire [IN_DATA-1:0] c3_row0;
wire [IN_DATA-1:0] c3_row1;
wire [IN_DATA-1:0] c3_row2 = c3_px;

// must buffer 2 previous rows
dlsc_ram_dp #(
    .DATA           ( 2*IN_DATA ),
    .ADDR           ( XBITS ),
    .DEPTH          ( IMG_WIDTH ),
    .PIPELINE_WR    ( 2 ),          // match read
    .PIPELINE_WR_DATA ( 0 ),
    .PIPELINE_RD    ( 2 )
) dlsc_ram_dp_inst (
    .write_clk      ( clk ),
    .write_en       ( c1_wr ),
    .write_addr     ( c1_x ),
    .write_data     ( { c3_row2, c3_row1 } ),   // write new row, and newest old row
    .read_clk       ( clk ),
    .read_en        ( c1_rd ),
    .read_addr      ( c1_x ),
    .read_data      ( { c3_row1, c3_row0 } )
);


// ** pipeline **

// get rows; maintain 3 pixel wide window
// const uint8_t *r0 = y > 0             ? in.ptr<uint8_t>(y-1) : in.ptr<uint8_t>(y+1);
// const uint8_t *r1 = in.ptr<uint8_t>(y);
// const uint8_t *r2 = y < (in.rows-1)   ? in.ptr<uint8_t>(y+1) : in.ptr<uint8_t>(y-1);
reg [IN_DATA-1:0]   c4_row0[2:0];
reg [IN_DATA-1:0]   c4_row1[2:0];
reg [IN_DATA-1:0]   c4_row2[2:0];

always @(posedge clk) begin
    if(c3_rd) begin
        c4_row0[0]  <= c4_row0[1];
        c4_row1[0]  <= c4_row1[1];
        c4_row2[0]  <= c4_row2[1];
        
        c4_row0[1]  <= c4_row0[2];
        c4_row1[1]  <= c4_row1[2];
        c4_row2[1]  <= c4_row2[2];

        c4_row0[2]  <= c3_y_first ? c3_row2 : c3_row0;
        c4_row1[2]  <=                        c3_row1;
        c4_row2[2]  <= c3_y_last  ? c3_row0 : c3_row2;
    end
end

// differences
// int d0  = r0[x+1] - r0[x-1];
// int d1  = r1[x+1] - r1[x-1];
// int d2  = r2[x+1] - r2[x-1];
reg [IN_DATA  :0]   c5_d0;
reg [IN_DATA  :0]   c5_d1;
reg [IN_DATA  :0]   c5_d2;

always @(posedge clk) begin
    if(c4_zero) begin
        // zero on first and last pixel of row
        // (results in output pixel being OUT_OFFSET)
        c5_d0       <= 0;
        c5_d1       <= 0;
        c5_d2       <= 0;
    end else begin
        c5_d0       <= {1'b0,c4_row0[2]} - {1'b0,c4_row0[0]};
        c5_d1       <= {1'b0,c4_row1[2]} - {1'b0,c4_row1[0]};
        c5_d2       <= {1'b0,c4_row2[2]} - {1'b0,c4_row2[0]};
    end
end

// sums
// int v   = d0 + 2*d1 + d2 + ftzero;
reg [IN_DATA+3:0]   c6_v0;
reg [IN_DATA+3:0]   c6_v1;

always @(posedge clk) begin
    c6_v0   <= {{3{c5_d0[IN_DATA]}},c5_d0} + {{2{c5_d1[IN_DATA]}},c5_d1,1'b0};
    c6_v1   <= {{3{c5_d2[IN_DATA]}},c5_d2} + out_offset;
end

reg [IN_DATA+3:0] c7_v;

always @(posedge clk) begin
    c7_v    <= c6_v0 + c6_v1;
end

// clamp
// if(v < 0) v = 0;
// else if(v > (2*ftzero)) v = (2*ftzero);
reg                 c8_clamp_zero;
reg                 c8_clamp_max;
reg [OUT_DATA-1:0]  c8_px;

/* verilator lint_off CMPCONST */
always @(posedge clk) begin
    c8_clamp_zero   <= c7_v[IN_DATA+3];                 // sign bit indicates it's negative
    c8_clamp_max    <= (c7_v[OUT_DATA-1:0] > out_clamp) || (|c7_v[IN_DATA+2:OUT_DATA]);
    c8_px           <= c7_v[OUT_DATA-1:0];
end
/* verilator lint_on CMPCONST */

reg [OUT_DATA-1:0]  c9_px;

always @(posedge clk) begin
    if(c8_clamp_zero) begin
        c9_px           <= 0;
    end else begin
        c9_px           <= c8_clamp_max ? out_clamp : c8_px;
    end
end


// ** output FIFO **

wire                fifo_out_pop;
wire                fifo_out_empty;
wire [OUT_DATA-1:0] fifo_out_px;

dlsc_fifo_shiftreg #(
    .DATA           ( OUT_DATA ),
    .DEPTH          ( 16 ),
    .ALMOST_FULL    ( 12 )          // must be enough to accomodate full pipeline stall
) dlsc_fifo_shiftreg_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .push_en        ( c9_en ),
    .push_data      ( c9_px ),
    .pop_en         ( fifo_out_pop ),
    .pop_data       ( fifo_out_px ),
    .empty          ( fifo_out_empty ),
    .full           (  ),
    .almost_empty   (  ),
    .almost_full    ( fifo_out_busy )
);


// ** register output **

assign fifo_out_pop = !fifo_out_empty && (out_ready || !out_valid);

always @(posedge clk) begin
    if(rst) begin
        out_valid   <= 1'b0;
    end else begin
        if(fifo_out_pop)
            out_valid   <= 1'b1;
        else if(out_ready)
            out_valid   <= 1'b0;
    end
end

always @(posedge clk) begin
    if(fifo_out_pop) begin
        out_px      <= fifo_out_px;
    end
end


endmodule

