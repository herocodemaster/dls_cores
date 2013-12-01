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
// Unsigned integer divider which can accept a new input every CYCLES clock cycles.
//
// Delay through module is:
//  For CYCLES ==  1, delay is QB+1 cycles (fully pipelined)
//  For CYCLES >= QB, delay is QB+2 cycles (fully sequential)
//  For other cases , delay is QB+4 cycles (hybrid)
//
// When using QSKIP, quotient width is effectively increased to QB+QSKIP, but with
// the QSKIP MSbits forced to 0. This option should only be used if there is a
// known relationship between the numerator and denominator that guarantees that
// these MSbits are really 0 (this is not checked by the divider).
//

module dlsc_divu #(
    parameter CYCLES    = 1,    // cycles allowed per division
    parameter NB        = 8,    // bits for numerator/dividend
    parameter DB        = NB,   // bits for denominator/divisor
    parameter QB        = NB,   // bits for quotient (<= NB+DB)
    parameter QSKIP     = 0     // MSbits of canonical quotient to skip (<= DB)
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

`dlsc_static_assert( (QB+QSKIP) <= (NB+DB) )
`dlsc_static_assert( QSKIP <= DB )

generate
if(CYCLES<=1) begin:GEN_PIPELINED

    dlsc_divu_pipe #(
        .NB         ( NB ),
        .DB         ( DB ),
        .QB         ( QB ),
        .QSKIP      ( QSKIP )
    ) dlsc_divu_pipe (
        .clk        ( clk ),
        .in_num     ( in_num ),
        .in_den     ( in_den ),
        .out_quo    ( out_quo )
    );

    dlsc_pipedelay_rst #(
        .DELAY      ( QB+1 ),
        .DATA       ( 1 ),
        .RESET      ( 1'b0 )
    ) dlsc_pipedelay_rst (
        .clk        ( clk ),
        .rst        ( rst ),
        .in_data    ( in_valid ),
        .out_data   ( out_valid )
    );

end else if(CYCLES>=QB) begin:GEN_SEQUENTIAL

    dlsc_divu_seq #(
        .NB         ( NB ),
        .DB         ( DB ),
        .QB         ( QB ),
        .QSKIP      ( QSKIP )
    ) dlsc_divu_seq (
        .clk        ( clk ),
        .in_valid   ( in_valid ),
        .in_num     ( in_num ),
        .in_den     ( in_den ),
        .out_quo    ( out_quo )
    );

    dlsc_pipedelay_rst #(
        .DELAY      ( QB+2 ),
        .DATA       ( 1 ),
        .RESET      ( 1'b0 )
    ) dlsc_pipedelay_rst (
        .clk        ( clk ),
        .rst        ( rst ),
        .in_data    ( in_valid ),
        .out_data   ( out_valid )
    );

end else begin:GEN_HYBRID

    dlsc_divu_hybrid #(
        .CYCLES     ( CYCLES ),
        .NB         ( NB ),
        .DB         ( DB ),
        .QB         ( QB ),
        .QSKIP      ( QSKIP )
    ) dlsc_divu_hybrid (
        .clk        ( clk ),
        .rst        ( rst ),
        .in_valid   ( in_valid ),
        .in_num     ( in_num ),
        .in_den     ( in_den ),
        .out_valid  ( out_valid ),
        .out_quo    ( out_quo )
    );

end
endgenerate

endmodule

