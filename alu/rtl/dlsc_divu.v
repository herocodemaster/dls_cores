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
// Implements a fully pipelined unsigned integer divider.
// Uses 1 adder per QUOTIENT bit (not efficient for large quotients).
// Pipeline delay is QUOTIENT or 2*QUOTIENT cycles (if PIPELINE is set).

module dlsc_divu #(
    parameter DIVIDEND      = 8,
    parameter DIVISOR       = 4,
    parameter QUOTIENT      = DIVIDEND, // delay through divider is QUOTIENT cycles
    parameter PIPELINE      = 0         // enable extra pipeline registers (when set, delay is 2*QUOTIENT cycles)
) (
    // system
    input   wire                    clk,

    // input
    input   wire    [DIVIDEND-1:0]  dividend,
    input   wire    [DIVISOR -1:0]  divisor,

    // output
    output  wire    [QUOTIENT-1:0]  quotient,
    output  wire    [DIVIDEND-1:0]  remainder
);

`include "dlsc_synthesis.vh"

localparam SUB = ( (QUOTIENT+DIVISOR) > (DIVIDEND) ) ? (QUOTIENT+DIVISOR) : (DIVIDEND);

// connections between divider stages
wire [QUOTIENT-1:0] q[QUOTIENT:0];
wire [DIVIDEND-1:0] t[QUOTIENT:0];
wire [DIVISOR -1:0] b[QUOTIENT:0];

// assign inputs
assign q[QUOTIENT]  = {QUOTIENT{1'b0}};
assign t[QUOTIENT]  = dividend;
assign b[QUOTIENT]  = divisor;

// assign outputs
assign quotient     = q[0];
assign remainder    = t[0];

generate
    genvar j;

    // 1 subtractor stage for each quotient bit
    for(j=0;j<QUOTIENT;j=j+1) begin:GEN_STAGES

        // register outputs of stage
        `DLSC_NO_SHREG reg [QUOTIENT-1:0] qr;   // registered quotient from previous stage, plus result from this stage
        `DLSC_NO_SHREG reg [DIVIDEND-1:0] tr;   // registered dividend from previous stage (used when result of this stage is '0')
        `DLSC_NO_SHREG reg [DIVIDEND-1:0] tsr;  // registered dividend from this stage (used when result of this stage is '1')
        `DLSC_NO_SHREG reg [DIVISOR -1:0] br;   // registered divisor

        // assign outputs of stage (inputs to next stage)
        if(PIPELINE==0) begin:GEN_NOPIPE

            assign q[j] = qr;
            assign t[j] = qr[j] ? tsr : tr;   // only send subtraction result if non-negative (i.e. this stage produced a '1')
            assign b[j] = br;

        end else begin:GEN_PIPE

            `DLSC_NO_SHREG reg [QUOTIENT-1:0] qrr;
            `DLSC_NO_SHREG reg [DIVIDEND-1:0] trr;
            `DLSC_NO_SHREG reg [DIVISOR -1:0] brr;

            assign q[j] = qrr;
            assign t[j] = trr;
            assign b[j] = brr;

            always @(posedge clk) begin
                qrr     <= qr;
                trr     <= qr[j] ? tsr : tr;
                brr     <= br;
            end

        end

        wire [SUB-1:0] sub;     // dividend - shifted_divisor
        wire           resn;    // sign of subtraction result (negative indicates shifter_divisor didn't fit, so result of stage is '0')

        wire [SUB  :0] left  = { {(1+SUB-DIVIDEND){1'b0}} , t[j+1] };       // dividend
        wire [SUB  :0] right = { {(1+SUB-DIVISOR ){1'b0}} , b[j+1] } << j;  // shifted divisor

        assign { resn, sub } = left - right;

        always @(posedge clk) begin
            tr      <= t[j+1];
            tsr     <= sub[DIVIDEND-1:0];
            br      <= b[j+1];
            qr      <= q[j+1];  // pass through result from previous stage..
            qr[j]   <= !resn;   // ..and set result for this stage
        end

    end

endgenerate


endmodule

