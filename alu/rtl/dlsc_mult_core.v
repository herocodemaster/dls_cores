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
// Integer multiplier (unsigned or signed). Will attempt to explicitly
// instantiate a suitable FPGA multiplier primitive, or will fall back to
// a generic inferrable multiplier.
// Optional pipelining improves performance. PIPELINE parameter
// sets number of cycles through multiplier (a value of 3-5 is recommended
// for Xilinx DSP48 blocks).

module dlsc_mult_core #(
    parameter DEVICE    = "GENERIC",
    parameter SIGNED    = 0,            // set for signed multiplication
    parameter DATA0     = 1,            // width of first operand (should typically be >= DATA1)
    parameter DATA1     = 1,            // width of second operand
    parameter OUT       = 1,            // width of output
    parameter PIPELINE  = 4             // pipeline delay (recommend 3-5 for Xilinx DSP48 blocks)
) (
    input   wire                clk,
    input   wire                clk_en,

    input   wire    [DATA0-1:0] in0,
    input   wire    [DATA1-1:0] in1,
    output  wire    [OUT  -1:0] out
);

`include "dlsc_synthesis.vh"
`include "dlsc_devices.vh"

localparam SIGNED0  = SIGNED;
localparam SIGNED1  = SIGNED;

localparam PIPE1    = (PIPELINE >= 1);
localparam PIPE2    = (PIPELINE >= 2);
localparam PIPE3    = (PIPELINE >= 3);
localparam PIPE4    = (PIPELINE >= 4);
localparam PIPE5    = (PIPELINE >= 5);

generate

`ifdef XILINX
if(DLSC_XILINX_DSP48A && (DATA0 <= 18) && (DATA1 <= 18) &&
    (SIGNED0 || (DATA0 <= 17) || (!SIGNED1 && DATA1 <= 17)) &&
    (SIGNED1 || (DATA1 <= 17) || (!SIGNED0 && DATA0 <= 17))
) begin:GEN_XILINX_DSP48A
    
    // Spartan-class DSP block
    // TODO: add support for other DSP slices

    // inputs
    wire [17:0] a = SIGNED0 ? { {(18-DATA0){in0[DATA0-1]}} , in0 } : { {(18-DATA0){1'b0}} , in0 };
    wire [17:0] b = SIGNED1 ? { {(18-DATA1){in1[DATA1-1]}} , in1 } : { {(18-DATA1){1'b0}} , in1 };
    wire [7:0]  opmode;

    assign opmode[1:0]  = 2'd1; // X mux: use multiplier product
    assign opmode[3:2]  = 2'd0; // Z mux: use constant 0
    assign opmode[4]    = 1'b0; // bypass port B/D pre-adder
    assign opmode[5]    = 1'b0; // no carry input
    assign opmode[6]    = 1'b0; // pre-adder is adder (doesn't matter)
    assign opmode[7]    = 1'b0; // post-adder is adder (doesn't matter)

    // outputs
    wire [47:0] p;

    DSP48A #(
        .PREG           ( PIPE1 ),      // Enable=1/disable=0 P output pipeline register
        .A1REG          ( PIPE2 ),      // Enable=1/disable=0 second stage A input pipeline register
        .B1REG          ( PIPE2 ),      // Enable=1/disable=0 second stage B input pipeline register
        .MREG           ( PIPE3 ),      // Enable=1/disable=0 M pipeline register
        .A0REG          ( PIPE5 ),      // Enable=1/disable=0 first stage A input pipeline register
        .B0REG          ( PIPE5 ),      // Enable=1/disable=0 first stage B input pipeline register
        .CARRYINREG     ( 1 ),          // Enable=1/disable=0 CARRYIN input pipeline register
        .CARRYINSEL     ( "OPMODE5" ),  // Specify carry-in source, "CARRYIN" or "OPMODE5" 
        .CREG           ( 1 ),          // Enable=1/disable=0 C input pipeline register
        .DREG           ( 1 ),          // Enable=1/disable=0 D pre-adder input pipeline register
        .OPMODEREG      ( 1 ),          // Enable=1/disable=0 OPMODE input pipeline register
        .RSTTYPE        ( "SYNC" )      // Specify reset type, "SYNC" or "ASYNC" 
    ) DSP48A_inst (
        .BCOUT          (  ),           // 18-bit B port cascade output
        .CARRYOUT       (  ),           // 1-bit carry output
        .P              ( p ),          // 48-bit output
        .PCOUT          (  ),           // 48-bit cascade output
        .A              ( a ),          // 18-bit A data input
        .B              ( b ),          // 18-bit B data input (can be connected to fabric or BCOUT of adjacent DSP48A)
        .C              ( 48'd0 ),      // 48-bit C data input
        .CARRYIN        ( 1'b0 ),       // 1-bit carry input signal
        .CEA            ( clk_en ),     // 1-bit active high clock enable input for A input registers
        .CEB            ( clk_en ),     // 1-bit active high clock enable input for B input registers
        .CEC            ( 1'b1 ),       // 1-bit active high clock enable input for C input registers
        .CECARRYIN      ( 1'b1 ),       // 1-bit active high clock enable input for CARRYIN registers
        .CED            ( 1'b0 ),       // 1-bit active high clock enable input for D input registers
        .CEM            ( clk_en ),     // 1-bit active high clock enable input for multiplier registers
        .CEOPMODE       ( 1'b1 ),       // 1-bit active high clock enable input for OPMODE registers
        .CEP            ( clk_en ),     // 1-bit active high clock enable input for P output registers
        .CLK            ( clk ),        // Clock input
        .D              ( 18'd0 ),      // 18-bit B pre-adder data input
        .OPMODE         ( opmode ),     // 8-bit operation mode input
        .PCIN           ( 48'd0 ),      // 48-bit P cascade input 
        .RSTA           ( 1'b0 ),       // 1-bit reset input for A input pipeline registers
        .RSTB           ( 1'b0 ),       // 1-bit reset input for B input pipeline registers
        .RSTC           ( 1'b0 ),       // 1-bit reset input for C input pipeline registers
        .RSTCARRYIN     ( 1'b0 ),       // 1-bit reset input for CARRYIN input pipeline registers
        .RSTD           ( 1'b0 ),       // 1-bit reset input for D input pipeline registers
        .RSTM           ( 1'b0 ),       // 1-bit reset input for M pipeline registers
        .RSTOPMODE      ( 1'b0 ),       // 1-bit reset input for OPMODE input pipeline registers
        .RSTP           ( 1'b0 )        // 1-bit reset input for P output pipeline registers
    );

    wire [OUT-1:0] ppipe;

    if(PIPE4) begin:GEN_PPIPE

        `DLSC_PIPE_REG reg [OUT-1:0] pr;
        assign ppipe = pr;
        
        always @(posedge clk) begin
            if(clk_en) begin
                pr <= p[OUT-1:0];
            end
        end

    end else begin:GEN_NO_PPIPE

        assign ppipe = p[OUT-1:0];

    end

    if(PIPELINE > 5) begin:GEN_OUT_PIPE

        dlsc_pipedelay_clken #(
            .DATA   ( OUT ),
            .DELAY  ( PIPELINE-5 )
        ) dlsc_pipedelay_clken (
            .clk        ( clk ),
            .clk_en     ( clk_en ),
            .in_data    ( ppipe ),
            .out_data   ( out )
        );

    end else begin:GEN_OUT

        assign out = ppipe;

    end

end else
`endif // XILINX

if(1) begin:GEN_GENERIC

    // Generic synthesizable multiplier

    dlsc_mult_generic #(
        .SIGNED         ( SIGNED ),
        .DATA0          ( DATA0 ),
        .DATA1          ( DATA1 ),
        .OUT            ( OUT ),
        .PIPELINE       ( PIPELINE )
    ) dlsc_mult_generic (
        .clk            ( clk ),
        .clk_en         ( clk_en ),
        .in0            ( in0 ),
        .in1            ( in1 ),
        .out            ( out )
    );

end
endgenerate

endmodule

