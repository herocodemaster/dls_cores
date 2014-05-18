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
// Pipeline delay module for use by processing modules that operate on
// accumulated windows of data.
// WIN_DELAY specifies how many samples the input needs to be delayed by to
// line up with the center of the window (typically, this is WIN/2).
// Until a full WIN_DELAY is accumulated, out_unmask is forced to 0 and out_data
// is invalid.
// The PIPE_DELAY parameter specifies a more conventional input-to-output
// pipeline delay value. This delay is applied after the window delay.

module dlsc_window_pipedelay #(
    parameter WIN_DELAY     = 0,
    parameter PIPE_DELAY    = 0,
    parameter META          = 0,
    // derived; don't touch
    parameter META1         = ((META>0) ? META : 1 )
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // input
    input   wire                    in_valid,
    input   wire                    in_unmask,
    input   wire    [META1-1:0]     in_meta,

    // output
    output  wire                    out_valid,
    output  wire                    out_unmask,
    output  wire    [META1-1:0]     out_meta
);

`include "dlsc_util.vh"

`dlsc_static_assert_gte(WIN_DELAY,0)
`dlsc_static_assert_gte(PIPE_DELAY,0)

// parameters for GEN_FIFO mode
localparam FDEPTH       = WIN_DELAY + PIPE_DELAY - 1;
localparam FADDR        = `dlsc_clog2(FDEPTH);

generate
if((WIN_DELAY<=0) && (PIPE_DELAY<=0)) begin:GEN_NONE

    // no delays at all

    assign out_valid    = in_valid;
    assign out_unmask   = in_unmask;
    assign out_meta     = (META>0) ? in_meta : 1'b0;

end else if((WIN_DELAY<=1) || (PIPE_DELAY<=1) || (META<=2)) begin:GEN_SIMPLE

    // simple delay mode
    // just use standard pipedelay modules

    // delay to center

    wire            ctr_unmask;

    dlsc_pipedelay_rst_clken #(
        .DELAY      ( WIN_DELAY ),
        .DATA       ( 1 ),
        .RESET      ( 1'b0 ),
        .FAST_RESET ( 0 )
    ) dlsc_pipedelay_rst_clken_center_unmask (
        .clk        ( clk ),
        .clk_en     ( in_valid ),
        .rst        ( rst ),
        .in_data    ( in_unmask ),
        .out_data   ( ctr_unmask )
    );

    // delay to output

    dlsc_pipedelay_rst #(
        .DELAY      ( PIPE_DELAY ),
        .DATA       ( 2 ),
        .RESET      ( 2'b00 ),
        .FAST_RESET ( 0 )
    ) dlsc_pipedelay_rst_out_unmask (
        .clk        ( clk ),
        .rst        ( rst ),
        .in_data    ( { ctr_unmask,  in_valid } ),
        .out_data   ( { out_unmask, out_valid } )
    );

    if(META>0) begin:GEN_META

        // delay to center

        wire [META-1:0] ctr_meta;

        dlsc_pipedelay_clken #(
            .DELAY      ( WIN_DELAY ),
            .DATA       ( META )
        ) dlsc_pipedelay_clken_center_meta (
            .clk        ( clk ),
            .clk_en     ( in_valid ),
            .in_data    ( in_meta ),
            .out_data   ( ctr_meta )
        );

        // delay to output

        dlsc_pipedelay #(
            .DELAY      ( PIPE_DELAY ),
            .DATA       ( META )
        ) dlsc_pipedelay_out_meta (
            .clk        ( clk ),
            .in_data    ( ctr_meta ),
            .out_data   ( out_meta )
        );

    end else begin:GEN_NO_META
        assign out_meta = 1'b0;
    end

end else begin:GEN_FIFO

    // combined window + output delay
    // both delays are at least 2 cycles each
    // meta is non-zero

    // control

    wire [FADDR-1:0]    pre_addr;

    dlsc_window_pipedelay_control #(
        .WIN_DELAY  ( WIN_DELAY ),
        .PIPE_DELAY ( PIPE_DELAY ),
        .FDEPTH     ( FDEPTH ),
        .FADDR      ( FADDR )
    ) dlsc_window_pipedelay_control (
        .clk        ( clk ),
        .rst        ( rst ),
        .in_valid   ( in_valid ),
        .in_unmask  ( in_unmask ),
        .out_valid  ( out_valid ),
        .out_unmask ( out_unmask ),
        .pre_primed_n (  ),
        .pre_addr   ( pre_addr )
    );

    // FIFO storage

    wire [META-1:0]     pre_meta;

    dlsc_shiftreg #(
        .DATA       ( META ),
        .ADDR       ( FADDR ),
        .DEPTH      ( FDEPTH ),
        .WARNINGS   ( 0 )
    ) dlsc_shiftreg (
        .clk        ( clk ),
        .write_en   ( in_valid ),
        .write_data ( in_meta ),
        .read_addr  ( pre_addr ),
        .read_data  ( pre_meta )
    );

    // drive output

    reg  [META-1:0]     out_meta_r;

    always @(posedge clk) begin
        out_meta_r  <= pre_meta;
    end
    
    assign out_meta = out_meta_r;

end
endgenerate

endmodule

