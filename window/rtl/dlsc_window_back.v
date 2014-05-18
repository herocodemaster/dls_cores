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
// Output buffer for pipeline segments that are fed by dlsc_window_front.

module dlsc_window_back #(
    parameter CYCLES        = 1,            // cycles per pixel
    parameter BITS          = 8,            // bits per pixel
    parameter DEPTH         = 32,           // depth of internal buffer (will be rounded up to nearest power-of-2)
    parameter FC_LATENCY    = 3,            // delay from fc_okay to fc_valid (typically 3 when paired with window_front)
    parameter WARNINGS      = 1             // enable warnings about inadequate depth
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // status
    output  reg                     done,       // entire frame has been accepted at output

    // control
    input   wire                    stall,      // auxilliary stall input; latency from stall to !fc_okay is 1 cycle

    // input from pipline
    input   wire                    in_valid,
    input   wire                    in_unmask,
    input   wire    [BITS-1:0]      in_data,

    // flow control from dlsc_window_front
    output  reg                     fc_okay,
    input   wire                    fc_valid,
    input   wire                    fc_unmask,
    input   wire                    fc_last,    // last pixel in frame
    input   wire                    fc_last_x,  // last pixel in row

    // output
    input   wire                    out_ready,
    output  reg                     out_valid,
    output  reg                     out_last,   // last pixel in frame
    output  reg                     out_last_x, // last pixel in row
    output  wire    [BITS-1:0]      out_data
);

`include "dlsc_util.vh"
`include "dlsc_synthesis.vh"

localparam ADDR     = `dlsc_clog2(DEPTH);
localparam DEPTHI   = (2**ADDR);
localparam LATI     = FC_LATENCY + 2; // TODO: confirm this is correct

`dlsc_static_assert_gt(DEPTHI,LATI)

// track pipeline occupancy

wire                outf_pop;

wire                cnt_inc     = fc_valid;
wire                cnt_deca    = in_valid && !in_unmask;   // dec for masked values (before output FIFO)
wire                cnt_decb    = outf_pop;                 // dec for unmasked values (after output FIFO)

reg  [ADDR-1:0]     cnt;
reg  [ADDR  :0]     next_cnt;

/* verilator lint_off WIDTH */
wire                cnt_okay    = (cnt < (DEPTHI-LATI));
/* verilator lint_on WIDTH */

always @* begin
    case({cnt_inc,cnt_deca,cnt_decb})
        3'b001:  next_cnt = {1'b0,cnt} - 1;    //     -1
        3'b010:  next_cnt = {1'b0,cnt} - 1;    //   -1
        3'b011:  next_cnt = {1'b0,cnt} - 2;    //   -1-1
        3'b100:  next_cnt = {1'b0,cnt} + 1;    // +1
        3'b111:  next_cnt = {1'b0,cnt} - 1;    // +1-1-1
        default: next_cnt = {1'b0,cnt};
    endcase
end

always @(posedge clk) begin
    if(rst) begin
        cnt <= 0;
    end else begin
        cnt <= next_cnt[ADDR-1:0];
    end
end

// buffer/delay metadata

wire                outf_push;

wire                fc_push     = fc_valid && fc_unmask;

wire                meta_almost_full;
wire                meta_okay   = !meta_almost_full;

wire                meta_last;
wire                meta_last_x;

dlsc_fifo #(
    .DATA           ( 2 ),
    .ADDR           ( ADDR ),
    .ALMOST_FULL    ( LATI ),
    .BRAM           ( 0 )
) dlsc_fifo_meta (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( fc_push ),
    .wr_data        ( { fc_last, fc_last_x } ),
    .wr_full        (  ),
    .wr_almost_full ( meta_almost_full ),
    .wr_free        (  ),
    .rd_pop         ( outf_push ),
    .rd_data        ( { meta_last, meta_last_x } ),
    .rd_empty       (  ),
    .rd_almost_empty (  ),
    .rd_count       (  )
);

// control

wire next_fc_okay = cnt_okay && meta_okay && !done && !stall;

always @(posedge clk) begin
    if(rst) begin
        done    <= 1'b0;
        fc_okay <= 1'b0;
    end else begin
        done    <= done || (out_ready && out_valid && out_last);
        fc_okay <= next_fc_okay;
    end
end

// buffer output

assign              outf_push   = in_valid && in_unmask;

wire                outf_empty;
assign              outf_pop    = !outf_empty && (!out_valid || (out_ready && CYCLES<=1));

wire                outf_last;
wire                outf_last_x;
wire [BITS-1:0]     outf_data;

dlsc_fifo #(
    .DATA           ( 2+BITS ),
    .ADDR           ( ADDR )
) dlsc_fifo_out (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( outf_push ),
    .wr_data        ( { meta_last, meta_last_x, in_data } ),
    .wr_full        (  ),
    .wr_almost_full (  ),
    .wr_free        (  ),
    .rd_pop         ( outf_pop ),
    .rd_data        ( { outf_last, outf_last_x, outf_data } ),
    .rd_empty       ( outf_empty ),
    .rd_almost_empty (  ),
    .rd_count       (  )
);

// drive output

always @(posedge clk) begin
    if(rst) begin
        out_valid <= 1'b0;
    end else begin
        if(out_ready) out_valid <= 1'b0;
        if(outf_pop ) out_valid <= 1'b1;
    end
end

`DLSC_PIPE_REG reg [BITS-1:0] out_data_r;
assign out_data = out_data_r;

always @(posedge clk) begin
    if(outf_pop) begin
        out_last    <= outf_last;
        out_last_x  <= outf_last_x;
        out_data_r  <= outf_data;
    end
end

// simulation checks

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

reg reported = 1'b0;

always @(posedge clk) begin
    if(rst) begin
        reported <= 1'b0;
    end else begin
        if(next_cnt[ADDR]) begin
            if(next_cnt[ADDR-1]) begin
                `dlsc_error("underflow");
            end else begin
                `dlsc_error("overflow");
            end
            if(!reported) begin
                dlsc_fifo_meta.report;
                dlsc_fifo_out.report;
                reported <= 1'b1;
            end
        end
        if(WARNINGS && !reported && !done && fc_valid && !next_fc_okay && !stall && outf_empty) begin
            `dlsc_warn("stalled with empty output FIFO");
            dlsc_fifo_meta.report;
            dlsc_fifo_out.report;
            reported <= 1'b1;
        end
    end
end

`include "dlsc_sim_bot.vh"
`endif

endmodule

