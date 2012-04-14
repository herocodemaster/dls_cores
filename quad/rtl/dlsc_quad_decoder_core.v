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
// Quadrature decoder with index support.
//
// Raw quadrature inputs are applied to in_a/b/z. These may come from top-level
// ports. Synchronization and filtering is performed inside the decoder.
//
// The 'FILTER' parameter sets the depth of the glitch filters.
// 'clk_en_filter' is a clock-enable for the glitch filters; when used, it can
// effectively increase the depth of the glitch filters.
//
// The synchronized and filtered quadrature inputs are available on the
// out_a/b/z/ ports.
//
// cfg_count_min/max set the range that the counter will count through. These
// can be two's complement. E.g. to count over the range [-10,10], you set:
//   cfg_count_min = 8'hF6
//   cfg_count_max = 8'h0A
//
// 'count_wrap_min' asserts if a decrement occurs when (count == cfg_count_min)
// 'count_wrap_max' asserts if an increment occurs when (count == cfg_count_max)
//
// Counter supports an atomic read & clear: 'count_read' will cause count to
// reset to 0 when sampled high. If a quadrature state change occurs on the
// same edge it will NOT be lost.
//
// 'cfg_index_qual' dynamically selects which quadrature states will respect
// the index pulse:
//   cfg_index_qual[0] => {in_b,in_a} == 2'b00
//   cfg_index_qual[1] => {in_b,in_a} == 2'b01
//   cfg_index_qual[2] => {in_b,in_a} == 2'b10
//   cfg_index_qual[3] => {in_b,in_a} == 2'b11
//
// If 'cfg_index_clr' is set, the counter will be cleared to 0 when a valid index
// pulse is observed.
//
// In general, changing the configuration inputs while the decoder is out of
// reset is a bad idea.
//
// 'error_index' asserts when an index pulse is observed while (count != 0)
// 'error_quad' asserts when an illegal quadrature state transition occurs
//
// All flag type outputs assert for a single cycle when their respective events
// occur; these outputs are:
//   quad_en
//   quad_index
//   count_wrap_min
//   count_wrap_max
//   error_index
//   error_quad
//

module dlsc_quad_decoder_core #(
    parameter FILTER            = 4,                // depth of glitch filters
    parameter BITS              = 16                // bits for counter
) (
    // system
    input   wire                clk,
    input   wire                clk_en_filter,      // clock enable (for glitch filters only)
    input   wire                rst,

    // configuration
    input   wire    [BITS-1:0]  cfg_count_min,      // counter counts [count_min,count_max] inclusive
    input   wire    [BITS-1:0]  cfg_count_max,      // ""
    input   wire    [3:0]       cfg_index_qual,     // select which states to look for index pulse in
    input   wire                cfg_index_clr,      // when asserted, index pulse will reset counter to 0

    // quadrature inputs
    input   wire                in_a,
    input   wire                in_b,
    input   wire                in_z,               // index

    // filtered quadrature signals
    output  reg                 out_a,
    output  reg                 out_b,
    output  reg                 out_z,

    // decoded quadrature signals
    output  reg                 quad_en,            // valid quadrature transition detected
    output  reg                 quad_dir,           // 1: incrementing, 0: decrementing
    output  reg                 quad_index,         // filtered and qualified index signal

    // counter
    input   wire                count_read,         // atomic clear
    output  reg     [BITS-1:0]  count,
    output  reg                 count_wrap_min,     // counter was at min and wrapped to max
    output  reg                 count_wrap_max,     // counter was at max and wrapped to min

    // index
    output  reg     [BITS-1:0]  index_count,        // count value sampled by index (prior to being cleared)

    // errors
    output  reg                 error_index,        // count was not 0 when index asserted
    output  reg                 error_quad          // illegal quadrature state transition (e.g. 00 -> 11)
);

// ** filters **

wire f_a;
wire f_b;
wire f_z;

dlsc_glitchfilter #(
    .DEPTH      ( FILTER )
) dlsc_glitchfilter_a (
    .clk        ( clk ),
    .clk_en     ( clk_en_filter ),
    .rst        ( 1'b0 ),
    .in         ( in_a ),
    .out        ( f_a )
);

dlsc_glitchfilter #(
    .DEPTH      ( FILTER )
) dlsc_glitchfilter_b (
    .clk        ( clk ),
    .clk_en     ( clk_en_filter ),
    .rst        ( 1'b0 ),
    .in         ( in_b ),
    .out        ( f_b )
);

dlsc_glitchfilter #(
    .DEPTH      ( FILTER )
) dlsc_glitchfilter_z (
    .clk        ( clk ),
    .clk_en     ( clk_en_filter ),
    .rst        ( 1'b0 ),
    .in         ( in_z ),
    .out        ( f_z )
);


// ** quad decode **

// NOTE: filters and prev-state registers are never reset; this allows tracking
// of encoder inputs during reset and prevents potential spurious assertion of
// 'error_quad' when reset is first removed

reg f_a_prev;
reg f_b_prev;
reg f_z_prev;

wire f_z_qual   = f_z && cfg_index_qual[{f_b,f_a}];         // qualify index signal with quadrature state

always @(posedge clk) begin
    f_a_prev    <= f_a;
    f_b_prev    <= f_b;
    f_z_prev    <= f_z_qual;
end

wire f_a_change = (f_a_prev != f_a);
wire f_b_change = (f_b_prev != f_b);

wire q_err      = (f_a_change && f_b_change);           // illegal state transition
wire q_en       = (f_a_change || f_b_change) && !q_err;
wire q_dir      = f_a_change ^ (f_a == f_b);            // increment when A leads B

wire q_index    = (!f_z_prev && f_z_qual);


// ** counter **

reg  [BITS-1:0] next_count;
reg  [BITS-1:0] next_index_count;

reg             set_count_wrap_min;
reg             set_count_wrap_max;
reg             set_error_index;

// TODO: complicated combinational logic; won't hit very high frequencies
// (not that anyone should be running a quadrature decoder at high frequencies..)
always @* begin
    next_count          = count;
    next_index_count    = index_count;
    set_count_wrap_min  = 1'b0;
    set_count_wrap_max  = 1'b0;
    set_error_index     = 1'b0;

    if(count_read) begin
        // atomic clear
        // cleared before handling any possible quadrature state changes, so
        // a change during read doesn't get lost
        next_count          = 0;
    end

    if(q_en) begin
        // quadrature state changed; count
        if(q_dir) begin
            // increment
            if(next_count == cfg_count_max) begin
                next_count          = cfg_count_min;
                set_count_wrap_max  = 1'b1;
            end else begin
                next_count          = next_count + 1;
            end
        end else begin
            // decrement
            if(next_count == cfg_count_min) begin
                next_count          = cfg_count_max;
                set_count_wrap_min  = 1'b1;
            end else begin
                next_count          = next_count - 1;
            end
        end
    end

    if(q_index) begin
        // index pulse; save count
        next_index_count    = next_count;

        // check value
        if(next_count != 0) begin
            set_error_index     = 1'b1;
        end

        // clear
        if(cfg_index_clr) begin
            next_count          = 0;
        end
    end
end


// ** register outputs **

always @(posedge clk) begin
    if(rst) begin
        count           <= 0;
        count_wrap_min  <= 1'b0;
        count_wrap_max  <= 1'b0;
        index_count     <= 0;
        error_index     <= 1'b0;
        error_quad      <= 1'b0;
        out_a           <= 1'b0;
        out_b           <= 1'b0;
        out_z           <= 1'b0;
        quad_en         <= 1'b0;
        quad_dir        <= 1'b0;
        quad_index      <= 1'b0;
    end else begin
        count           <= next_count;
        count_wrap_min  <= set_count_wrap_min;
        count_wrap_max  <= set_count_wrap_max;
        index_count     <= next_index_count;
        error_index     <= set_error_index;
        error_quad      <= q_err;
        out_a           <= f_a;
        out_b           <= f_b;
        out_z           <= f_z;
        quad_en         <= q_en;
        if(q_en) begin
            quad_dir        <= q_dir;
        end
        quad_index      <= q_index;
    end
end        


endmodule

