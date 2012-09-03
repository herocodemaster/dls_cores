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
// Accumulates a horizontal window of pixels. Supports multiple modes for
// handling edge cases (via EDGE_MODE parameter):
//  NONE:   Output is only produced once outside of an edge region. Output
//          is reduced in width: out_width = in_width - (WIN-1)
//  FILL:   Pixels outside of the input are filled with a constant value
//          (supplied via the cfg_fill input).
//  REPEAT: Pixels outside of the input are filled with their nearest valid
//          neighbor.
//  MIRROR: Pixels outside of the input are filled by mirroring the row around
//          the nearest valid neighbor. This mode requires more logic than other
//          modes, and is not recommended for large windows.
//
// Delay from input to output is 1 cycle for EDGE_MODE == "NONE" and 2 cycles
// for all other modes.

module dlsc_window_x #(
    parameter BUFFER        = 0,            // depth of input buffer FIFO
    parameter WIN           = 3,            // size of accumulated window (odd)
    parameter BITS          = 8,            // bits per pixel
    parameter EDGE_MODE     = "REPEAT"      // NONE, FILL, REPEAT, MIRROR
) (
    // system
    input   wire                        clk,
    input   wire                        rst,

    // configuration
    input   wire    [BITS-1:0]          cfg_fill,       // fill value (only for EDGE_MODE == "FILL")

    // input
    output  wire                        in_ready,
    input   wire                        in_valid,
    input   wire                        in_last,        // last pixel in row
    input   wire    [BITS-1:0]          in_data,

    // output
    input   wire                        out_ready,      // note: fanout inside module is large (proportional to window size)
    output  reg                         out_valid,
    output  reg                         out_last,       // last pixel in row
    output  reg     [(WIN*BITS)-1:0]    out_data        // packed output.. 0 is oldest/leftmost pixel
);

`include "dlsc_clog2.vh"

integer i;
integer j;

/* verilator lint_off WIDTH */
localparam EM_FILL      = (EDGE_MODE == "FILL")     || (EDGE_MODE == 1);
localparam EM_REPEAT    = (EDGE_MODE == "REPEAT")   || (EDGE_MODE == 2);
localparam EM_MIRROR    = (EDGE_MODE == "MIRROR")   || (EDGE_MODE == 3);
localparam EM_NONE      = !(EM_FILL || EM_REPEAT || EM_MIRROR);
/* verilator lint_on WIDTH */

localparam CENTER       = (WIN/2);
localparam RIGHT        = WIN-1;

localparam STNB         = `dlsc_clog2(WIN);         // bits for state in EM_NONE
localparam STMB         = `dlsc_clog2(CENTER+1);    // bits for state in EM_MIRROR

`ifdef SIMULATION
/* verilator coverage_off */
// check configuration parameters
initial begin
    if((WIN%2) != 1) begin
        $display("[%m] *** ERROR *** WIN (%0d) must be odd", WIN);
        $finish;
    end
end
/* verilator coverage_on */
`endif

generate
if(WIN<=1) begin:GEN_WIN1

    // pass-through for window size of 1

    assign in_ready = out_ready;

    always @* begin
        out_valid   = in_valid;
        out_last    = in_last;
        out_data    = in_data;
    end

end else begin:GEN_WIN

    // buffering

    wire            c0_update;
    wire            c0_last;
    wire [BITS-1:0] c0_data;

    if(BUFFER>0) begin:GEN_BUFFER

        wire            wr_full;
        wire            rd_empty;
        
        assign          in_ready        = !wr_full;

        assign          c0_update       = out_ready && !rd_empty;

        dlsc_fifo #(
            .DEPTH          ( BUFFER ),
            .DATA           ( 1+BITS )
        ) dlsc_fifo (
            .clk            ( clk ),
            .rst            ( rst ),
            .wr_push        ( in_ready && in_valid ),
            .wr_data        ( { in_last, in_data } ),
            .wr_full        ( wr_full ),
            .wr_almost_full (  ),
            .wr_free        (  ),
            .rd_pop         ( c0_update ),
            .rd_data        ( { c0_last, c0_data } ),
            .rd_empty       ( rd_empty ),
            .rd_almost_empty (  ),
            .rd_count       (  )
        );

    end else begin:GEN_NO_BUFFER

        assign          in_ready        = out_ready;

        assign          c0_update       = in_ready && in_valid;
        assign          c0_last         = in_last;
        assign          c0_data         = in_data;

    end

    reg  [BITS-1:0] out_data_r [WIN-1:0];

    always @* begin
        out_data    = 0;
        for(i=0;i<WIN;i=i+1) begin
            out_data[ (i*BITS) +: BITS ] = out_data_r[i];
        end
    end

    if(EM_NONE) begin:GEN_EM_NONE

        // No edge handling. Output is only valid when a complete window has been
        // accumulated. Output is smaller than input.

        reg  [STNB-1:0] cnt;
        reg             cnt_zero;

        always @(posedge clk) begin
            if(rst) begin
                cnt         <= WIN-1;
                cnt_zero    <= 1'b0;
                out_valid   <= 1'b0;
                out_last    <= 1'b0;
            end else begin
                if(out_ready) begin
                    out_valid   <= 1'b0;
                    out_last    <= 1'b0;
                end
                if(c0_update) begin
                    if(cnt_zero) begin
                        out_valid   <= 1'b1;
                        out_last    <= c0_last;
                    end else begin
                        cnt         <= cnt - 1;
                        cnt_zero    <= (cnt == 1);
                    end
                    if(c0_last) begin
                        cnt         <= WIN-1;
                        cnt_zero    <= 1'b0;
                    end
                end
            end
        end

        reg  [BITS-1:0] c1_data [WIN-1:0];

        always @(posedge clk) if(c0_update) begin
            for(i=0;i<RIGHT;i=i+1) begin
                out_data_r[i]       <= out_data_r[i+1];
            end
            out_data_r[RIGHT]   <= c0_data;
        end

    end else begin:GEN_EM_ANY

        // Output is valid once half of a window has been accumulated. Output is
        // the same size as the input.
        
        // control

        reg             c0_first;
        reg             c0_row;

        always @(posedge clk) begin
            if(rst) begin
                c0_first    <= 1'b1;
                c0_row      <= 1'b0;
            end else if(c0_update) begin
                c0_first    <= 1'b0;
                if(c0_last) begin
                    c0_first    <= 1'b1;
                    c0_row      <= !c0_row;
                end
            end
        end

        // Track state of each pixel in the window.
        // Many of these fields aren't always used. Hopefully the optimizer is smart
        // enough to prune them.

        reg  [WIN-1:0]  c1_valid;
        reg  [WIN-1:0]  c1_row;
        reg  [WIN-1:0]  c1_first;
        reg  [WIN-1:0]  c1_last;
        reg  [BITS-1:0] c1_data [WIN-1:0];

        reg  [WIN-1:0]  c1_update;
        reg  [WIN-1:0]  c1_next_valid;
        reg  [WIN-1:0]  c1_next_row;
        reg  [WIN-1:0]  c1_next_first;
        reg  [WIN-1:0]  c1_next_last;

        always @* begin
            c1_update           = 0;
            c1_next_valid       = c1_valid;
            c1_next_row         = c1_row;
            c1_next_first       = c1_first;
            c1_next_last        = c1_last;

            c1_update[RIGHT]    = out_ready && (c0_update || (c1_row[RIGHT] != c0_row));
            if(c1_update[RIGHT]) begin
                c1_next_valid[RIGHT]= c0_update;
                c1_next_row[RIGHT]  = c0_row;
                c1_next_first[RIGHT]= c0_first;
                c1_next_last[RIGHT] = c0_last;
            end

            for(i=(RIGHT-1);i>=0;i=i-1) begin
                c1_update[i]        = out_ready && (c0_update || (c1_row[i] != c0_row));
                if(c1_update[i]) begin
                    c1_next_valid[i]    = (c1_update[i+1] && c1_valid[i+1]);
                    c1_next_row[i]      = c1_row[i+1];
                    c1_next_first[i]    = c1_first[i+1];
                    c1_next_last[i]     = c1_last[i+1];
                end
            end
        end

        always @(posedge clk) begin
            if(rst) begin
                c1_valid        <= 0;
            end else begin
                c1_valid        <= c1_next_valid;
            end
        end

        always @(posedge clk) begin
            c1_row          <= c1_next_row;
            c1_first        <= c1_next_first;
            c1_last         <= c1_next_last;

            for(i=0;i<RIGHT;i=i+1) begin
                if(c1_update[i]) begin
                    c1_data[i]      <= c1_data[i+1];
                end
            end

            if(c1_update[RIGHT]) begin
                c1_data[RIGHT]  <= c0_data;
            end
        end

        always @(posedge clk) begin
            if(rst) begin
                out_valid   <= 1'b0;
                out_last    <= 1'b0;
            end else begin
                if(out_ready) begin
                    out_valid   <= 1'b0;
                    out_last    <= 1'b0;
                end
                if(c1_update[CENTER]) begin
                    out_valid   <= c1_valid[CENTER];
                    out_last    <= c1_last[CENTER];
                end
            end
        end

        if(EM_FILL) begin:GEN_EM_FILL

            // Edges are filled with a constant value.

            always @(posedge clk) if(c1_update[CENTER]) begin
                // left
                for(i=0;i<CENTER;i=i+1) begin
                    out_data_r[i]       <= (c1_valid[i] && (c1_row[i] == c1_row[CENTER])) ? c1_data[i] : cfg_fill;
                end
                // center
                out_data_r[CENTER]  <= c1_data[CENTER];
                // right
                for(i=(CENTER+1);i<=RIGHT;i=i+1) begin
                    out_data_r[i]       <= (c1_valid[i] && (c1_row[i] == c1_row[CENTER])) ? c1_data[i] : cfg_fill;
                end
            end

        end

        if(EM_REPEAT) begin:GEN_EM_REPEAT

            // Edges are filled by repeating the nearest valid pixel (left is filled
            // with first pixel; right is filled with last pixel)

            reg  [BITS-1:0] c1_data_first;
            reg  [BITS-1:0] c1_data_last;
            
            always @(posedge clk) if(c0_update) begin
                if(c0_first) begin
                    c1_data_first   <= c0_data;
                end
                if(c0_last) begin
                    c1_data_last    <= c0_data;
                end
            end

            always @(posedge clk) if(c1_update[CENTER]) begin
                // left
                for(i=0;i<CENTER;i=i+1) begin
                    out_data_r[i]       <= (c1_valid[i] && (c1_row[i] == c1_row[CENTER])) ? c1_data[i] : c1_data_first;
                end
                // center
                out_data_r[CENTER]  <= c1_data[CENTER];
                // right
                for(i=(CENTER+1);i<=RIGHT;i=i+1) begin
                    out_data_r[i]       <= (c1_valid[i] && (c1_row[i] == c1_row[CENTER])) ? c1_data[i] : c1_data_last;
                end
            end

        end

        if(EM_MIRROR) begin:GEN_EM_MIRROR

            // Edges are filled by mirroring data around the nearest valid pixel.
            // Most costly option. Not recommended for large window sizes.
            // Left is filled like:
            // ... 2 1 0 1 2 3 4 ...
            // Right is filled like:
            // ... 6 7 8 9 10 9 8 ...

            reg  [STMB-1:0] st_left;
            reg  [STMB-1:0] st_right;

            always @(posedge clk) begin
                if(rst) begin
                    st_left     <= 0;
                    st_right    <= 0;
                end else if(c1_update[CENTER+1]) begin
                    /* verilator lint_off WIDTH */
                    if(st_left != 0) begin
                        st_left     <= st_left - 1;
                    end
                    if(st_right != 0 && st_right != CENTER) begin
                        st_right    <= st_right + 1;
                    end
                    if(c1_first[CENTER+1] && c1_valid[CENTER+1]) begin
                        st_left     <= CENTER;
                        st_right    <= 0;
                    end else if(c1_last[RIGHT] && c1_valid[RIGHT]) begin
                        st_right    <= 1;
                    end
                    /* verilator lint_on WIDTH */
                end
            end

            always @(posedge clk) if(c1_update[CENTER]) begin
                /* verilator lint_off WIDTH */

                // left
                for(i=0;i<CENTER;i=i+1) begin
                    out_data_r[i]   <= c1_data[i];
                    for(j=1;j<=(CENTER-i);j=j+1) begin
                        if(st_left == (j+(i-0))) begin
                            out_data_r[i]   <= c1_data[i+(j*2)];
                        end
                    end
                end
                
                // center
                out_data_r[CENTER] <= c1_data[CENTER];

                // right
                for(i=(CENTER+1);i<=RIGHT;i=i+1) begin
                    out_data_r[i]   <= c1_data[i];
                    for(j=1;j<=(i-CENTER);j=j+1) begin
                        if(st_right == (j+(RIGHT-i))) begin
                            out_data_r[i]   <= c1_data[i-(j*2)];
                        end
                    end
                end

                /* verilator lint_on WIDTH */
            end

        end

    end // GEN_EM_ANY

end // GEN_WIN
endgenerate

endmodule

