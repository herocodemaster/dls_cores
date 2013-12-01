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
// Partially pipeline unsigned integer divider.
// Computes 1 division every CYCLES cycles.
// Delay from input to output is QB+4 cycles.

module dlsc_divu_hybrid #(
    parameter CYCLES    = 1,    // cycles allowed per division (>= 2; < QB)
    parameter NB        = 8,    // bits for numerator/dividend
    parameter DB        = NB,   // bits for denominator/divisor
    parameter QB        = NB,   // bits for quotient
    parameter QSKIP     = 0     // MSbits of canonical quotient to skip
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // input
    input   wire                    in_valid,
    input   wire    [NB-1:0]        in_num,
    input   wire    [DB-1:0]        in_den,

    // output
    output  wire                    out_valid,
    output  wire    [QB-1:0]        out_quo
);

`include "dlsc_util.vh"
`include "dlsc_synthesis.vh"

genvar j;

localparam SLICES   = (QB+CYCLES-1)/CYCLES;
localparam SLCB     = `dlsc_clog2(SLICES);
localparam CYCB     = `dlsc_clog2(CYCLES);

reg  [SLICES-1:0]   c0_slice;

always @(posedge clk) begin
    if(rst) begin
        c0_slice    <= 1;
    end else if(in_valid) begin
        c0_slice    <= { c0_slice[SLICES-2:0], c0_slice[SLICES-1] };
    end
end

`DLSC_PIPE_REG reg [SLICES-1:0] c1_valid;
`DLSC_PIPE_REG reg [NB-1:0]     c1_num;
`DLSC_PIPE_REG reg [DB-1:0]     c1_den;

always @(posedge clk) begin
    c1_valid    <= in_valid ? c0_slice : 0;
    c1_num      <= in_num;
    c1_den      <= in_den;
end

wire [QB-1:0]       co0_quo [SLICES-1:0];

generate
for(j=0;j<SLICES;j=j+1) begin:GEN_SLICES

    dlsc_divu_seq #(
        .NB         ( NB ),
        .DB         ( DB ),
        .QB         ( QB ),
        .QSKIP      ( QSKIP )
    ) dlsc_divu_seq (
        .clk        ( clk ),
        .in_valid   ( c1_valid[j] ),
        .in_num     ( c1_num ),
        .in_den     ( c1_den ),
        .out_quo    ( co0_quo[j] )
    );

end
endgenerate

localparam CO0 = 1 + QB+2;

wire                co0_valid;

dlsc_pipedelay_rst #(
    .DATA       ( 1 ),
    .DELAY      ( CO0 - 0 )
) dlsc_pipedelay_rst (
    .clk        ( clk ),
    .rst        ( rst ),
    .in_data    ( in_valid ),
    .out_data   ( co0_valid )
);

reg  [SLCB-1:0]     co0_slice;
wire                co0_slice_last  = (co0_slice == (SLICES-1));

always @(posedge clk) begin
    if(rst) begin
        co0_slice   <= 0;
    end else if(co0_valid) begin
        co0_slice   <= co0_slice + 1;
        if(co0_slice_last) begin
            co0_slice   <= 0;
        end
    end
end

reg co1_valid;

always @(posedge clk) begin
    if(rst) begin
        co1_valid   <= 1'b0;
    end else begin
        co1_valid   <= co0_valid;
    end
end

`DLSC_PIPE_REG reg [QB-1:0] co1_quo;

always @(posedge clk) begin
    co1_quo     <= co0_quo[co0_slice];
end

assign out_valid    = co1_valid;
assign out_quo      = co1_quo;

endmodule

