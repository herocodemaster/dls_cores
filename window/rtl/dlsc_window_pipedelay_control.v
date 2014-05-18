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
// Common control logic for pipdelay_window when operating in GEN_FIFO mode.

module dlsc_window_pipedelay_control #(
    parameter WIN_DELAY     = 0,
    parameter PIPE_DELAY    = 0,
    parameter FDEPTH        = 2,    // depth of delay FIFO
    parameter FADDR         = 1     // address bits for delay FIFO
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // input
    input   wire                    in_valid,
    input   wire                    in_unmask,

    // output
    output  reg                     out_valid,
    output  reg                     out_unmask,

    // control
    output  wire                    pre_primed_n,
    output  reg     [FADDR-1:0]     pre_addr
);

`include "dlsc_util.vh"

localparam WIN2B            = `dlsc_clog2(WIN_DELAY);

// delay unmask

wire ctr_unmask;
    
dlsc_pipedelay_rst_clken #(
    .DELAY      ( WIN_DELAY ),
    .DATA       ( 1 ),
    .RESET      ( 1'b0 ),
    .FAST_RESET ( 0 )
) dlsc_pipedelay_rst_clken_center (
    .clk        ( clk ),
    .clk_en     ( in_valid ),
    .rst        ( rst ),
    .in_data    ( in_unmask ),
    .out_data   ( ctr_unmask )
);

// delay valid to 1 cycle before output

wire pre_valid;
wire pre_unmask;

dlsc_pipedelay_rst #(
    .DELAY      ( PIPE_DELAY-1 ),
    .DATA       ( 2 ),
    .RESET      ( 2'b00 ),
    .FAST_RESET ( 0 )
) dlsc_pipedelay_rst_out (
    .clk        ( clk ),
    .rst        ( rst ),
    .in_data    ( { ctr_unmask,  in_valid } ),
    .out_data   ( { pre_unmask, pre_valid } )
);

// track window priming state

reg [WIN2B:0] pre_cnt;

assign pre_primed_n = pre_cnt[WIN2B]; // primed once cnt reaches (2**WIN2B)-1

always @(posedge clk) begin
    if(rst) begin
        /* verilator lint_off WIDTH */
        pre_cnt     <= (2**WIN2B) + WIN_DELAY - 1;
        /* verilator lint_on WIDTH */
    end else if(pre_valid && pre_primed_n) begin
        pre_cnt     <= pre_cnt - 'd1;
    end
end

// delay data using simple FIFO
// based on dlsc_fifo_shiftreg (minus flags)

wire pre_pop = pre_valid && !pre_primed_n;

always @(posedge clk) begin
    if(rst) begin
        pre_addr    <= {FADDR{1'b1}}; // -1 when empty
    end else if(in_valid ^ pre_pop) begin
        pre_addr    <= in_valid ? (pre_addr + 'd1) : (pre_addr - 'd1);
    end
end

// drive output

always @(posedge clk) begin
    if(rst) begin
        out_valid   <= 1'b0;
        out_unmask  <= 1'b0;
    end else begin
        out_valid   <= pre_valid;
        out_unmask  <= pre_unmask;
    end
end

endmodule

