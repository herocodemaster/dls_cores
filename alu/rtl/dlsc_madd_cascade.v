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
// Implements a cascade of madd units. Uses dedicated cascade connections
// within supported FPGAs.

module dlsc_madd_cascade #(
    parameter DEVICE        = "GENERIC",
    parameter SLICES        = 1,        // number of slices to cascade
    parameter REVERSE       = 0,        // reverse order of cascade (start at N-1 instead of 0)
    parameter SIGNED        = 0,        // treat inputs as signed values
    parameter AB            = 8,        // bits for A inputs (should typically be >= BB)
    parameter BB            = 8,        // bits for B inputs
    parameter SIB           = AB+BB,    // bits for sum in
    parameter SOB           = SIB       // bits for sum out (>= SIB)
) (
    // system
    input   wire                        clk,

    // inputs
    // will get re-registered internally
    input   wire    [SLICES*AB-1:0]     c0_a,
    input   wire    [SLICES*BB-1:0]     c0_b,

    // sum in
    input   wire    [SIB-1:0]           c4_sum_in,

    // sum out
    // has pipeline delay of [4 + SLICES] cycles
    // co = c4 + SLICES
    // note: sum_out may come directly from DSP slice output register (which has a long clk-to-out delay)
    output  wire    [SOB-1:0]           co_sum_out
);

`include "dlsc_synthesis.vh"
`include "dlsc_devices.vh"

genvar j;

// re-register inputs

wire [SLICES*AB-1:0] c1_a;
wire [SLICES*BB-1:0] c1_b;

generate
for(j=0;j<SLICES;j=j+1) begin:GEN_C1

    `DLSC_PIPE_REG reg [AB-1:0] c1_a_r;
    `DLSC_PIPE_REG reg [BB-1:0] c1_b_r;

    if(REVERSE) begin:GEN_REVERSE
        always @(posedge clk) begin
            c1_a_r  <= c0_a[ (SLICES-1-j)*AB +: AB ];
            c1_b_r  <= c0_b[ (SLICES-1-j)*BB +: BB ];
        end
    end else begin:GEN_FORWARD
        always @(posedge clk) begin
            c1_a_r  <= c0_a[ j*AB +: AB ];
            c1_b_r  <= c0_b[ j*BB +: BB ];
        end
    end

    assign c1_a[ j*AB +: AB ] = c1_a_r;
    assign c1_b[ j*BB +: BB ] = c1_b_r;

end

`ifdef XILINX
if((DLSC_XILINX_DSP48 || DLSC_XILINX_DSP48A) && AB <= 17 && BB <= 17 && SOB <= 48) begin:GEN_XILINX_DSP48

    // DSP48 and derivatives need 48-bit cascade

    wire [47:0] cascade [SLICES:0];

    assign cascade[0] = SIGNED ?
        { {(48-SIB){c4_sum_in[SIB-1]}} , c4_sum_in } :
        { {(48-SIB){1'b0}} , c4_sum_in };

    assign co_sum_out = cascade[SLICES][SOB-1:0];

    for(j=0;j<SLICES;j=j+1) begin:GEN_SLICES
        dlsc_madd #(
            .DEVICE         ( DEVICE ),
            .SIGNED         ( SIGNED ),
            .AB             ( AB ),
            .BB             ( BB ),
            .SB             ( 48 ),
            .CASCADE_IN     ( j != 0 ),
            .CASCADE_OUT    ( j != (SLICES-1) )
        ) dlsc_madd (
            .clk            ( clk ),
            .c0_a           ( c1_a[ j*AB +: AB ] ),
            .c0_b           ( c1_b[ j*BB +: BB ] ),
            .c3_sum_in      ( cascade[j] ),
            .c4_sum_out     ( cascade[j+1] )
        );
    end

end else
`endif // XILINX

begin:GEN_GENERIC

    // Generic; cascade can just be SOB
    // TODO: use optimized adder cascade

    wire [SOB-1:0] cascade [SLICES:0];

    assign cascade[0] = SIGNED ?
        { {(SOB-SIB){c4_sum_in[SIB-1]}} , c4_sum_in } :
        { {(SOB-SIB){1'b0}} , c4_sum_in };

    assign co_sum_out = cascade[SLICES];

    for(j=0;j<SLICES;j=j+1) begin:GEN_SLICES
        dlsc_madd #(
            .DEVICE         ( DEVICE ),
            .SIGNED         ( SIGNED ),
            .AB             ( AB ),
            .BB             ( BB ),
            .SB             ( SOB ),
            .CASCADE_IN     ( j != 0 ),
            .CASCADE_OUT    ( j != (SLICES-1) )
        ) dlsc_madd (
            .clk            ( clk ),
            .c0_a           ( c1_a[ j*AB +: AB ] ),
            .c0_b           ( c1_b[ j*BB +: BB ] ),
            .c3_sum_in      ( cascade[j] ),
            .c4_sum_out     ( cascade[j+1] )
        );
    end

end
endgenerate

endmodule

