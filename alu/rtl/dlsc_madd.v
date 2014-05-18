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
// Implements a multiplier followed by an adder. Maps efficiently to FPGA DSP slices.
// When cascading madd units, dlsc_madd_cascade should be used in order to ensure
// that the dedicated cascade connections within the FPGA are used.

module dlsc_madd #(
    parameter DEVICE        = "GENERIC",
    parameter SIGNED        = 0,        // treat inputs as signed values
    parameter AB            = 8,        // bits for input A (should typically be >= BB)
    parameter BB            = 8,        // bits for input B
    parameter SB            = AB+BB,    // bits for sum; must be >= AB+BB
    parameter CASCADE_IN    = 0,        // indicates sum_in comes from another madd instance (which must have CASCADE_OUT set)
    parameter CASCADE_OUT   = 0         // indicates sum_out drives another madd instance (which must have CASCADE_IN set)
) (
    // system
    input   wire                        clk,

    // input
    input   wire    [AB-1:0]            c0_a,
    input   wire    [BB-1:0]            c0_b,

    // sum in
    input   wire    [SB-1:0]            c3_sum_in,

    // sum out
    output  wire    [SB-1:0]            c4_sum_out
);

`include "dlsc_devices.vh"

localparam MB = AB+BB; // bits for result of multiply operation

generate

`ifdef XILINX
if(DLSC_XILINX_DSP48A && AB <= 17 && BB <= 17) begin:GEN_XILINX_DSP48A

    // Spartan-class DSP block
    // TODO: add support for other DSP slices

    // inputs
    wire [17:0] a;
    wire [17:0] b;

    if(!SIGNED) begin:GEN_UNSIGNED
        assign a = { {(18-AB){1'b0}} , c0_a };
        assign b = { {(18-BB){1'b0}} , c0_b };
    end else begin:GEN_SIGNED
        assign a = { {(18-AB){c0_a[AB-1]}} , c0_a };
        assign b = { {(18-BB){c0_b[BB-1]}} , c0_b };
    end

    wire [47:0] c;
    wire [47:0] pcin;
    wire [7:0]  opmode;

    // outputs
    wire [47:0] p;
    wire [47:0] pcout;

    DSP48A #(
        .A0REG          ( 1 ),          // Enable=1/disable=0 first stage A input pipeline register
        .A1REG          ( 1 ),          // Enable=1/disable=0 second stage A input pipeline register
        .B0REG          ( 1 ),          // Enable=1/disable=0 first stage B input pipeline register
        .B1REG          ( 1 ),          // Enable=1/disable=0 second stage B input pipeline register
        .CARRYINREG     ( 1 ),          // Enable=1/disable=0 CARRYIN input pipeline register
        .CARRYINSEL     ( "OPMODE5" ),  // Specify carry-in source, "CARRYIN" or "OPMODE5" 
        .CREG           ( 1 ),          // Enable=1/disable=0 C input pipeline register
        .DREG           ( 1 ),          // Enable=1/disable=0 D pre-adder input pipeline register
        .MREG           ( 1 ),          // Enable=1/disable=0 M pipeline register
        .OPMODEREG      ( 1 ),          // Enable=1/disable=0 OPMODE input pipeline register
        .PREG           ( 1 ),          // Enable=1/disable=0 P output pipeline register
        .RSTTYPE        ( "SYNC" )      // Specify reset type, "SYNC" or "ASYNC" 
    ) DSP48A_inst (
        .BCOUT          (  ),           // 18-bit B port cascade output
        .CARRYOUT       (  ),           // 1-bit carry output
        .P              ( p ),          // 48-bit output
        .PCOUT          ( pcout ),      // 48-bit cascade output
        .A              ( a ),          // 18-bit A data input
        .B              ( b ),          // 18-bit B data input (can be connected to fabric or BCOUT of adjacent DSP48A)
        .C              ( c ),          // 48-bit C data input
        .CARRYIN        ( 1'b0 ),       // 1-bit carry input signal
        .CEA            ( 1'b1 ),       // 1-bit active high clock enable input for A input registers
        .CEB            ( 1'b1 ),       // 1-bit active high clock enable input for B input registers
        .CEC            ( 1'b1 ),       // 1-bit active high clock enable input for C input registers
        .CECARRYIN      ( 1'b1 ),       // 1-bit active high clock enable input for CARRYIN registers
        .CED            ( 1'b1 ),       // 1-bit active high clock enable input for D input registers
        .CEM            ( 1'b1 ),       // 1-bit active high clock enable input for multiplier registers
        .CEOPMODE       ( 1'b1 ),       // 1-bit active high clock enable input for OPMODE registers
        .CEP            ( 1'b1 ),       // 1-bit active high clock enable input for P output registers
        .CLK            ( clk ),        // Clock input
        .D              ( 18'd0 ),      // 18-bit B pre-adder data input
        .OPMODE         ( opmode ),     // 8-bit operation mode input
        .PCIN           ( pcin ),       // 48-bit P cascade input 
        .RSTA           ( 1'b0 ),       // 1-bit reset input for A input pipeline registers
        .RSTB           ( 1'b0 ),       // 1-bit reset input for B input pipeline registers
        .RSTC           ( 1'b0 ),       // 1-bit reset input for C input pipeline registers
        .RSTCARRYIN     ( 1'b0 ),       // 1-bit reset input for CARRYIN input pipeline registers
        .RSTD           ( 1'b0 ),       // 1-bit reset input for D input pipeline registers
        .RSTM           ( 1'b0 ),       // 1-bit reset input for M pipeline registers
        .RSTOPMODE      ( 1'b0 ),       // 1-bit reset input for OPMODE input pipeline registers
        .RSTP           ( 1'b0 )        // 1-bit reset input for P output pipeline registers
    );

    assign opmode[1:0]  = 2'd1; // X mux: use multiplier product
    assign opmode[4]    = 1'b0; // bypass port B/D pre-adder
    assign opmode[5]    = 1'b0; // no carry input
    assign opmode[6]    = 1'b0; // pre-adder is adder (doesn't matter)
    assign opmode[7]    = 1'b0; // post-adder is adder

    if(CASCADE_IN) begin:GEN_CASCADE_IN

        assign c    = 48'd0;
        assign pcin = c3_sum_in;

        assign opmode[3:2] = 2'd1;  // Z mux: use PCIN

    end else begin:GEN_NO_CASCADE_IN

        assign c    = c3_sum_in;
        assign pcin = 48'd0;
        
        assign opmode[3:2] = 2'd3;  // Z mux: use C port

    end

    if(CASCADE_OUT) begin:GEN_CASCADE_OUT

        assign c4_sum_out   = pcout;

    end else begin:GEN_NO_CASCADE_OUT

        assign c4_sum_out   = p;

    end

end else
`endif // XILINX

begin:GEN_GENERIC

    // Generic synthesizable multiplier

    if(!SIGNED) begin:GEN_UNSIGNED

        // input registers
        // use both sets of DSP slice input registers

        reg [AB-1:0] c1_a, c2_a;
        reg [BB-1:0] c1_b, c2_b;

        always @(posedge clk) begin
            { c2_a, c1_a } <= { c1_a, c0_a };
            { c2_b, c1_b } <= { c1_b, c0_b };
        end

        // multiply

        reg [MB-1:0] c3_mult;

        always @(posedge clk) begin
            c3_mult <= c2_a * c2_b;
        end

        // accumulate

        reg [SB-1:0] c4_sum;

        always @(posedge clk) begin
            c4_sum  <= c3_sum_in + { {(SB-MB){1'b0}} , c3_mult };
        end

        // drive output

        assign c4_sum_out = c4_sum;

    end else begin:GEN_SIGNED

        // input registers
        // use both sets of DSP slice input registers

        reg signed [AB-1:0] c1_a, c2_a;
        reg signed [BB-1:0] c1_b, c2_b;

        always @(posedge clk) begin
            { c2_a, c1_a } <= { c1_a, c0_a };
            { c2_b, c1_b } <= { c1_b, c0_b };
        end

        // multiply

        reg signed [MB-1:0] c3_mult;

        always @(posedge clk) begin
            c3_mult <= c2_a * c2_b;
        end

        // accumulate

        reg signed [SB-1:0] c4_sum;

        always @(posedge clk) begin
            c4_sum  <= $signed(c3_sum_in) + { {(SB-MB){c3_mult[MB-1]}} , c3_mult };
        end

        // drive output

        assign c4_sum_out = c4_sum;

    end

end
endgenerate

endmodule

