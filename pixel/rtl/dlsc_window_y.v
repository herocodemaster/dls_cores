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
//
// Generates a vertical window of pixels from an incoming pixel stream. Supports
// multiple modes for handling edge cases (via EDGE_MODE parameter):
//  NONE:   Output is only produced once outside of an edge region. Output
//          is reduced in height: out_height = in_height - (WIN-1)
//  FILL:   Rows outside of the input are filled with a constant value
//          (supplied via the cfg_fill input).
//  REPEAT: Rows outside of the input are filled with their nearest valid
//          neighbor.
//  MIRROR: Rows outside of the input are filled by mirroring around the
//          nearest valid row. This mode requires more logic than other modes,
//          and is not recommended for large windows.
//
// Delay from input to output is 3 cycles for EDGE_MODE == "NONE" and 4 cycles
// for all other modes.

module dlsc_window_y #(
    parameter WIN           = 3,            // size of accumulated window (odd)
    parameter MAX_X         = 1024,         // max input image width
    parameter XB            = 10,           // bits for MAX_X-1
    parameter BITS          = 8,            // bits per pixel
    parameter EDGE_MODE     = "REPEAT",     // NONE, FILL, REPEAT, MIRROR
    parameter USE_LAST_X    = 0             // when set, uses in_last_x instead of cfg_x.. only valid for EDGE_MODE = NONE
) (
    // system
    input   wire                        clk,
    input   wire                        rst,

    // configuration
    input   wire    [XB-1:0]            cfg_x,          // row width; latched on 1st pixel of frame; 0 based (not used when USE_LAST_X is set)
    input   wire    [BITS-1:0]          cfg_fill,       // fill value (only for EDGE_MODE = FILL)

    // input
    output  wire                        in_ready,
    input   wire                        in_valid,
    input   wire                        in_last_x,      // last pixel in row (only used when USE_LAST_X is set)
    input   wire                        in_last,        // last pixel in frame
    input   wire    [BITS-1:0]          in_data,

    // output
    input   wire                        out_stall,      // must be asserted at least 4 cycles before downstream client can no longer receive data
    output  reg                         out_valid,
    output  reg                         out_last_x,     // last pixel in row
    output  reg                         out_last,       // last pixel in frame
    output  reg     [(WIN*BITS)-1:0]    out_data        // packed output.. 0 is oldest/topmost pixel
);

`include "dlsc_util.vh"

integer i;
integer j;
genvar k;

/* verilator lint_off WIDTH */
localparam EM_FILL      = (EDGE_MODE == "FILL")     || (EDGE_MODE == 1);
localparam EM_REPEAT    = (EDGE_MODE == "REPEAT")   || (EDGE_MODE == 2);
localparam EM_MIRROR    = (EDGE_MODE == "MIRROR")   || (EDGE_MODE == 3);
localparam EM_NONE      = !(EM_FILL || EM_REPEAT || EM_MIRROR);
/* verilator lint_on WIDTH */

localparam CENTER       = (WIN/2);

localparam ADDR         = `dlsc_clog2(MAX_X);       // address bits for row memory
localparam CNTB         = `dlsc_max( 1, (EM_NONE ? `dlsc_clog2(WIN) : `dlsc_clog2(CENTER)) );

`ifdef SIMULATION
/* verilator coverage_off */
// check configuration parameters
initial begin
    if((WIN%2) != 1) begin
        $display("[%m] *** ERROR *** WIN (%0d) must be odd", WIN);
        $finish;
    end
    if(USE_LAST_X && !EM_NONE) begin
        $display("[%m] *** ERROR *** USE_LAST_X can only be set with EDGE_MODE = NONE");
        $finish;
    end
end
/* verilator coverage_on */
`endif

generate
if(WIN<=1) begin:GEN_WIN1

    // pass-through for window size of 1

    assign in_ready = !out_stall;

    always @* begin
        out_valid   = in_ready && in_valid;
        out_last_x  = in_last_x;    // TODO: out_last_x not generated for !USE_LAST_X case
        out_last    = in_last;
        out_data    = in_data;
    end

end else begin:GEN_WIN

    // ** control **

    reg             c0_first;       // first pixel of frame
    reg  [XB-1:0]   c0_cfg_x;       // cfg_x latched on first pixel

    always @(posedge clk) begin
        if(rst) begin
            c0_first    <= 1'b1;
            /* verilator lint_off WIDTH */
            c0_cfg_x    <= MAX_X-1;
            /* verilator lint_on WIDTH */
        end else if(in_ready && in_valid) begin
            c0_first    <= in_last;
            if(c0_first && !(EM_NONE && USE_LAST_X)) begin
                c0_cfg_x    <= cfg_x;
            end
        end
    end

    localparam  ST_FILL = 2'd0,     // priming row buffer before producing any output
                ST_PRE  = 2'd1,     // producing output for upper edge case
                ST_RUN  = 2'd2,     // producing normal output (no edge cases to handle)
                ST_POST = 2'd3;     // producing output for lower edge case.. running entirely off of buffered rows
    
    reg  [1:0]      c0_st;

    /* verilator lint_off WIDTH */
    reg  [CNTB-1:0] c0_cnt;
    wire            c0_cnt_last     = EM_NONE ? (c0_cnt == (WIN-2)) : (c0_cnt == (CENTER-1));
    /* verilator lint_on WIDTH */

    reg  [ADDR-1:0] c0_addr;
    wire            c0_addr_last    = (EM_NONE && USE_LAST_X) ? in_last_x : (c0_addr == c0_cfg_x[ADDR-1:0]);

    assign          in_ready        = ( EM_NONE || c0_st != ST_POST) && !out_stall;
    wire            c0_update       = (!EM_NONE && c0_st == ST_POST  && !out_stall) || (in_ready && in_valid);
    wire            c0_valid        = c0_update && (c0_st != ST_FILL);

    reg             c0_last;

    reg  [1:0]      c0_next_st;
    reg  [CNTB-1:0] c0_next_cnt;
    reg  [ADDR-1:0] c0_next_addr;

    always @* begin
        c0_last         = 1'b0;
        c0_next_st      = c0_st;
        c0_next_cnt     = c0_cnt;
        c0_next_addr    = c0_addr + 1;
        
        if(c0_addr_last) begin
            c0_next_addr    = 0;

            c0_next_cnt     = c0_cnt + 1;
            if(c0_cnt_last || c0_st == ST_RUN) begin
                c0_next_cnt     = 0;
            end

            if(c0_st == ST_FILL && c0_cnt_last) begin
                // done priming row buffer
                c0_next_st      = EM_NONE ? ST_RUN : ST_PRE;
            end

            if(c0_st == ST_PRE && c0_cnt_last && !EM_NONE) begin
                // done with partial top rows
                c0_next_st      = ST_RUN;
            end

            if(c0_st == ST_RUN && in_last) begin
                // done with input rows
                c0_next_st      = EM_NONE ? ST_FILL : ST_POST;
                c0_last         = EM_NONE ? 1'b1 : 1'b0;
            end

            if(c0_st == ST_POST && c0_cnt_last && !EM_NONE) begin
                // done with partial bottom rows
                c0_next_st      = ST_FILL;
                c0_last         = 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if(rst) begin
            c0_st       <= ST_FILL;
            c0_cnt      <= 0;
            c0_addr     <= 0;
        end else if(c0_update) begin
            c0_st       <= c0_next_st;
            c0_cnt      <= c0_next_cnt;
            c0_addr     <= c0_next_addr;
        end
    end

    // ** row buffering **

    reg             c1_valid;
    reg  [ADDR-1:0] c1_addr;

    always @(posedge clk) begin
        if(rst) begin
            c1_valid    <= 1'b0;
            c1_addr     <= 0;
        end else begin
            c1_valid    <= c0_update;
            c1_addr     <= c0_addr;
        end
    end

    wire            c3_valid;
    wire            c3_last_x;
    wire            c3_last;
    wire [BITS-1:0] c3_in_data;

    dlsc_pipedelay_valid #(
        .DATA       ( 2+BITS ),
        .DELAY      ( 3-0 )
    ) dlsc_pipedelay_valid_c0_c3 (
        .clk        ( clk ),
        .rst        ( rst ),
        .in_valid   ( c0_valid ),
        .in_data    ( { c0_addr_last, c0_last, in_data } ),
        .out_valid  ( c3_valid ),
        .out_data   ( { c3_last_x, c3_last, c3_in_data } )
    );

    wire [(WIN*BITS)-1:0] c3_data_pre;
    assign c3_data_pre[ ((WIN-1)*BITS) +: BITS ] = c3_in_data;

    dlsc_ram_dp #(
        .DATA           ( (WIN-1)*BITS ),
        .ADDR           ( ADDR ),
        .DEPTH          ( MAX_X ),
        .PIPELINE_WR    ( 2 ),          // match read
        .PIPELINE_WR_DATA ( 0 ),        // ""
        .PIPELINE_RD    ( 2 )
    ) dlsc_ram_dp (
        .write_clk      ( clk ),
        .write_en       ( c1_valid ),
        .write_addr     ( c1_addr ),
        .write_data     ( c3_data_pre[ BITS +: ((WIN-1)*BITS) ] ),
        .read_clk       ( clk ),
        .read_en        ( c1_valid ),
        .read_addr      ( c1_addr ),
        .read_data      ( c3_data_pre[    0 +: ((WIN-1)*BITS) ] )
    );

    wire [BITS-1:0] c3_data [WIN-1:0];

    for(k=0;k<WIN;k=k+1) begin:GEN_C2_DATA
        assign c3_data[k] = c3_data_pre[ (k*BITS) +: BITS ];
    end

    // ** output packing **

    reg  [BITS-1:0] out_data_r [WIN-1:0];

    always @* begin
        out_data    = 0;
        for(i=0;i<WIN;i=i+1) begin
            out_data[ (i*BITS) +: BITS ] = out_data_r[i];
        end
    end

    // ** edge handling **

    if(EM_NONE) begin:GEN_EM_NONE

        // No edge handling. Output is only valid when a complete window has been
        // accumulated. Output is smaller than input.

        always @* begin
            out_valid   = c3_valid;
            out_last_x  = c3_last_x;
            out_last    = c3_last;
            for(i=0;i<WIN;i=i+1) begin
                out_data_r[i] = c3_data[i];
            end
        end

    end else begin:GEN_EM_ANY

        // Output is valid once half of a window has been accumulated. Output is
        // the same size as the input.
        
        // ** control **
    
        wire [1:0]      c3_st;
        wire [CNTB-1:0] c3_cnt;

        dlsc_pipedelay #(
            .DATA       ( 2+CNTB ),
            .DELAY      ( 3-0 )
        ) dlsc_pipedelay_c0_c3 (
            .clk        ( clk ),
            .in_data    ( { c0_st, c0_cnt } ),
            .out_data   ( { c3_st, c3_cnt } )
        );

        always @(posedge clk) begin
            if(rst) begin
                out_valid   <= 1'b0;
                out_last_x  <= 1'b0;
                out_last    <= 1'b0;
            end else begin
                out_valid   <= c3_valid;
                out_last_x  <= c3_last_x;
                out_last    <= c3_last;
            end
        end

        // ** muxing **

        if(EM_FILL) begin:GEN_EM_FILL

            // Edges are filled with a constant value.

            /* verilator lint_off WIDTH */
            always @(posedge clk) if(c3_valid) begin
                // top
                for(i=0;i<CENTER;i=i+1) begin
                    out_data_r[i]       <= ((c3_st != ST_PRE ) || (c3_cnt > (CENTER-1-i))) ? c3_data[i] : cfg_fill;
                end
                // center
                out_data_r[CENTER]  <= c3_data[CENTER];
                // bottom
                for(i=(CENTER+1);i<WIN;i=i+1) begin
                    out_data_r[i]       <= ((c3_st != ST_POST) || (c3_cnt < (WIN   -1-i))) ? c3_data[i] : cfg_fill;
                end
            end
            /* verilator lint_on WIDTH */

        end

        if(EM_REPEAT) begin:GEN_EM_REPEAT

            // Edges are filled by repeating the nearest valid row.

            reg  [BITS-1:0] c3_data_top;
            reg  [BITS-1:0] c3_data_bot;

            /* verilator lint_off WIDTH */
            always @* begin
                c3_data_top = {BITS{1'bx}};
                c3_data_bot = {BITS{1'bx}};
                for(i=0;i<CENTER;i=i+1) begin
                    if(c3_cnt == i) begin
                        c3_data_top = c3_data[CENTER-i];
                        c3_data_bot = c3_data[WIN-2-i];
                    end
                end
            end

            always @(posedge clk) if(c3_valid) begin
                // top
                for(i=0;i<CENTER;i=i+1) begin
                    out_data_r[i]       <= ((c3_st != ST_PRE ) || (c3_cnt > (CENTER-1-i))) ? c3_data[i] : c3_data_top;
                end
                // center
                out_data_r[CENTER]  <= c3_data[CENTER];
                // bottom
                for(i=(CENTER+1);i<WIN;i=i+1) begin
                    out_data_r[i]       <= ((c3_st != ST_POST) || (c3_cnt < (WIN   -1-i))) ? c3_data[i] : c3_data_bot;
                end
            end
            /* verilator lint_on WIDTH */

        end

        if(EM_MIRROR) begin:GEN_EM_MIRROR

            // Edges are filled by mirroring data around the nearest valid row.
            // Most costly option. Not recommended for large window sizes.
            
            /* verilator lint_off WIDTH */
            always @(posedge clk) if(c3_valid) begin

                // top
                for(i=0;i<CENTER;i=i+1) begin
                    out_data_r[i]       <= c3_data[i];
                    if(c3_st == ST_PRE) begin
                        for(j=0;j<=(CENTER-1-i);j=j+1) begin
                            if(c3_cnt == j) begin
                                out_data_r[i]       <= c3_data[ ((CENTER-j)-i) + (CENTER-j) ];  // distance_from_mirror_row + mirror_row_pos
                            end
                        end
                    end
                end

                // center
                out_data_r[CENTER]  <= c3_data[CENTER];

                // bottom
                for(i=(CENTER+1);i<WIN;i=i+1) begin
                    out_data_r[i]       <= c3_data[i];
                    if(c3_st == ST_POST) begin
                        for(j=(WIN-1-i);j<CENTER;j=j+1) begin
                            if(c3_cnt == j) begin
                                out_data_r[i]       <= c3_data[ (2*CENTER-j-1) - (i-(2*CENTER-j-1)) ];  // mirror_row_pos - distance_from_mirror_row
                            end
                        end
                    end
                end

            end
            /* verilator lint_on WIDTH */

        end

    end // GEN_EM_ANY

end // GEN_WIN
endgenerate

endmodule


