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
// Non-pipelined 32x32-bit unsigned/signed multiplier (suitable for a CPU core).
// Optimized for Xilinx DSP48 slices (but should work reasonably well with any
// pipelined 18x18-bit multiplier primitives).
//
// Usage:
// Supply inputs 'in0' and 'in1', and assert 'sign' if inputs are signed;
// Assert 'start' signal to latch inputs;
// Multiplication operation starts when 'start' is subsequently deasserted;
// 'done' will assert coincident with 'out' containing the result
// (done will assert ~6 cycles after start is deasserted)
// Asserting 'start' again before 'done' is asserted will terminate the
// current multiplication.

module dlsc_mult32 #(
    parameter DEVICE        = "GENERIC",
    parameter REGISTER      = 1,
    parameter REGISTER_IN   = REGISTER,     // register in0/in1 (otherwise connect directly to multiplier block)
    parameter REGISTER_OUT  = REGISTER      // register out[63:34] (otherwise connect directly to multiplier block)
) (
    input   wire                clk,

    input   wire    [31:0]      in0,
    input   wire    [31:0]      in1,
    
    input   wire                sign,
    input   wire                start,

    output  wire    [63:0]      out,
    output  reg                 done,       // out[63:0] is valid
    output  reg                 done33,     // out[33:0] is valid
    output  reg                 done16      // out[16:0] is valid
);

`include "dlsc_devices.vh"

// save inputs when started
reg signed [17:0] in0_lo;
reg signed [17:0] in0_hi;
reg signed [17:0] in1_lo;
reg signed [17:0] in1_hi;

always @(posedge clk) begin
    if(start) begin
        in0_lo[17: 0]   <= { 1'b0, in0[16:0] };
        in1_lo[17: 0]   <= { 1'b0, in1[16:0] };
        in0_hi[14: 0]   <= in0[31:17];
        in1_hi[14: 0]   <= in1[31:17];
        // sign-extend if needed
        in0_hi[17:15]   <= sign ? {3{in0[31]}} : 3'h0;
        in1_hi[17:15]   <= sign ? {3{in1[31]}} : 3'h0;
    end
end


// control
reg  [2:0]  cnt;

reg         mult_a_sel;
reg         mult_b_sel;
reg  [1:0]  mult_c_sel;

localparam C_ZERO   = 2'b00,
           C_PREG   = 2'b10,
           C_PR17   = 2'b11;

reg  [2:0]  out_en  = 3'h0;
reg         active  = 1'b0;

wire        ce_in   = active || (!REGISTER_IN && start);
wire        ce_ctrl = active;
wire        ce_m    = active;
wire        ce_p    = active;

always @(posedge clk) begin
    if(start) begin

        if(REGISTER_IN) begin
            cnt         <= 0;
            mult_a_sel  <= 1'b0;
            mult_b_sel  <= 1'b0;
            mult_c_sel  <= C_ZERO;
        end else begin
            // skip state 0
            cnt         <= 1;
            mult_a_sel  <= 1'b1;
            mult_b_sel  <= 1'b0;
            mult_c_sel  <= C_ZERO;
        end

        out_en      <= 3'h0;

        done        <= 1'b0;
        done33      <= 1'b0;
        done16      <= 1'b0;
        active      <= 1'b1;

    end else if(active) begin

        cnt         <= cnt + 1;

        out_en      <= 3'h0;

        case(cnt)

            0: begin
                // 1st applied to inputs
                mult_a_sel  <= 1'b1;
                mult_b_sel  <= 1'b0;
                mult_c_sel  <= C_ZERO;
            end
            1: begin
                // 2nd applied to inputs
                // 1st through a1/b1 reg
                mult_a_sel  <= 1'b0;
                mult_b_sel  <= 1'b1;
                mult_c_sel  <= C_PR17;
            end
            2: begin
                // 3rd applied to inputs
                // 2nd through a1/b1 reg
                // 1st through mreg
                mult_a_sel  <= 1'b1;
                mult_b_sel  <= 1'b1;
                mult_c_sel  <= C_PREG;
                out_en[0]   <= 1'b1;
            end
            3: begin
                // 4th applied to inputs
                // 3rd through a1/b1 reg
                // 2nd through mreg
                // 1st through preg
                mult_c_sel  <= C_PR17;
                done16      <= 1'b1;
            end
            4: begin    
                // 4th through a1/b1 reg
                // 3rd through mreg
                // 2nd through preg
                // 1st through output
                out_en[1]   <= 1'b1;
            end
            5: begin
                // 4th through mreg
                // 3rd through preg
                // 2nd through output
                // 1st through output
                done33      <= 1'b1;
                if(REGISTER_OUT) begin
                    out_en[2]   <= 1'b1;
                end else begin
                    done        <= 1'b1;
                    active      <= 1'b0;
                end
            end
            6: begin
                // 4th through preg
                // 3rd through output
                // 2nd through output
                // 1st through output
                if(REGISTER_OUT) begin
                    done        <= 1'b1;
                    active      <= 1'b0;
                end
            end

        endcase

    end
end


// multipler inputs
reg signed [17:0] mult_a;
reg signed [17:0] mult_b;

always @* begin
    if(!REGISTER_IN && start) begin
        // bypass input directly to multiplier
        mult_a = { 1'b0, in0[16:0] };
        mult_b = { 1'b0, in1[16:0] };
    end else begin
        mult_a = mult_a_sel ? in0_hi : in0_lo;
        mult_b = mult_b_sel ? in1_hi : in1_lo;
    end
end

// output
wire signed [47:0] p;
reg [63:0] out_r;

always @(posedge clk) begin
    if(out_en[0]) out_r[16: 0] <= p[16:0];
    if(out_en[1]) out_r[33:17] <= p[16:0];
    if(out_en[2]) out_r[63:34] <= p[29:0];
end

assign out = REGISTER_OUT ? out_r : { p[29:0], out_r[33:0] };

// multiplier
generate

`ifdef XILINX
if(`DLSC_XILINX_DSP48) begin:GEN_XILINX_DSP48

    // Virtex-class DSP block

    reg [6:0] opmode;
    always @* begin
        opmode[1:0] = 2'd1; // post-adder X input from multiplier (partial-product 1)
        opmode[3:2] = 2'd1; // post-adder Y input from multiplier (partial-product 2)
        // post-adder Z input
        case(mult_c_sel)
            C_ZERO:  opmode[6:4] = 3'd0; // 0
            C_PREG:  opmode[6:4] = 3'd2; // from P register
            C_PR17:  opmode[6:4] = 3'd6; // shifted P register (P >>> 17)
            default: opmode[6:4] = 3'hX;
        endcase
    end

    DSP48 #(
        .AREG           ( 1 ),          // Number of pipeline registers on the A input, 0, 1 or 2
        .BREG           ( 1 ),          // Number of pipeline registers on the B input, 0, 1 or 2
        .B_INPUT        ( "DIRECT" ),   // B input DIRECT from fabric or CASCADE from another DSP48
        .CARRYINREG     ( 1 ),          // Number of pipeline registers for the CARRYIN input, 0 or 1
        .CARRYINSELREG  ( 1 ),          // Number of pipeline registers for the CARRYINSEL, 0 or 1
        .CREG           ( 1 ),          // Number of pipeline registers on the C input, 0 or 1
        .LEGACY_MODE    ( "MULT18X18S" ), // Backward compatibility, NONE, MULT18X18 or MULT18X18S
        .MREG           ( 1 ),          // Number of multiplier pipeline registers, 0 or 1
        .OPMODEREG      ( 1 ),          // Number of pipeline regsiters on OPMODE input, 0 or 1
        .PREG           ( 1 ),          // Number of pipeline registers on the P output, 0 or 1
        .SUBTRACTREG    ( 1 )           // Number of pipeline registers on the SUBTRACT input, 0 or 1
    ) DSP48_inst (
        .BCOUT          (  ),           // 18-bit B cascade output
        .P              ( p ),          // 48-bit product output
        .PCOUT          (  ),           // 48-bit cascade output
        .A              ( mult_a ),     // 18-bit A data input
        .B              ( mult_b ),     // 18-bit B data input
        .BCIN           ( 18'd0 ),      // 18-bit B cascade input
        .C              ( 48'd0 ),      // 48-bit cascade input
        .CARRYIN        ( 1'b0 ),       // Carry input signal
        .CARRYINSEL     ( 2'b00 ),      // 2-bit carry input select
        .CEA            ( ce_in ),      // A data clock enable input
        .CEB            ( ce_in ),      // B data clock enable input
        .CEC            ( 1'b0 ),       // C data clock enable input
        .CECARRYIN      ( 1'b0 ),       // CARRYIN clock enable input
        .CECINSUB       ( ce_ctrl ),    // CINSUB clock enable input
        .CECTRL         ( ce_ctrl ),    // Clock Enable input for CTRL regsiters
        .CEM            ( ce_m ),       // Clock Enable input for multiplier regsiters
        .CEP            ( ce_p ),       // Clock Enable input for P regsiters
        .CLK            ( clk ),        // Clock input
        .OPMODE         ( opmode ),     // 7-bit operation mode input
        .PCIN           ( 48'd0 ),      // 48-bit PCIN input 
        .RSTA           ( 1'b0 ),       // Reset input for A pipeline registers
        .RSTB           ( 1'b0 ),       // Reset input for B pipeline registers
        .RSTC           ( 1'b0 ),       // Reset input for C pipeline registers
        .RSTCARRYIN     ( 1'b0 ),       // Reset input for CARRYIN registers
        .RSTCTRL        ( 1'b0 ),       // Reset input for CTRL registers
        .RSTM           ( 1'b0 ),       // Reset input for multiplier registers
        .RSTP           ( 1'b0 ),       // Reset input for P pipeline registers
        .SUBTRACT       ( 1'b0 )        // SUBTRACT input
    );

end else if(`DLSC_XILINX_DSP48A) begin:GEN_XILINX_DSP48A

    // Spartan-class DSP block

    reg [7:0] opmode;
    always @* begin
        opmode[1:0] = 2'd1; // post-adder X input from multiplier
        opmode[4]   = 1'b0; // bypass pre-adder
        opmode[5]   = 1'b0; // carry-in 0
        opmode[6]   = 1'b0; // pre-adder adds
        opmode[7]   = 1'b0; // post-adder adds
        // post-adder Z input
        case(mult_c_sel)
            C_ZERO:  opmode[3:2] = 2'd0; // 0
            C_PREG:  opmode[3:2] = 2'd2; // from P register
            C_PR17:  opmode[3:2] = 2'd3; // from C port (P >>> 17)
            default: opmode[3:2] = 2'hX;
        endcase
    end

    wire [47:0] mult_c = { {17{p[47]}}, p[47:17] };

    DSP48A #(
        .A0REG          ( 0 ),          // Enable=1/disable=0 first stage A input pipeline register
        .A1REG          ( 1 ),          // Enable=1/disable=0 second stage A input pipeline register
        .B0REG          ( 0 ),          // Enable=1/disable=0 first stage B input pipeline register
        .B1REG          ( 1 ),          // Enable=1/disable=0 second stage B input pipeline register
        .CARRYINREG     ( 1 ),          // Enable=1/disable=0 CARRYIN input pipeline register
        .CARRYINSEL     ( "CARRYIN" ),  // Specify carry-in source, "CARRYIN" or "OPMODE5" 
        .CREG           ( 0 ),          // Enable=1/disable=0 C input pipeline register
        .DREG           ( 1 ),          // Enable=1/disable=0 D pre-adder input pipeline register
        .MREG           ( 1 ),          // Enable=1/disable=0 M pipeline register
        .OPMODEREG      ( 1 ),          // Enable=1/disable=0 OPMODE input pipeline register
        .PREG           ( 1 ),          // Enable=1/disable=0 P output pipeline register
        .RSTTYPE        ( "SYNC" )      // Specify reset type, "SYNC" or "ASYNC" 
    ) DSP48A_inst (
        .BCOUT          (  ),           // 18-bit B port cascade output
        .CARRYOUT       (  ),           // 1-bit carry output
        .P              ( p ),          // 48-bit output
        .PCOUT          (  ),           // 48-bit cascade output
        .A              ( mult_a ),     // 18-bit A data input
        .B              ( mult_b ),     // 18-bit B data input (can be connected to fabric or BCOUT of adjacent DSP48A)
        .C              ( mult_c ),     // 48-bit C data input
        .CARRYIN        ( 1'b0 ),       // 1-bit carry input signal
        .CEA            ( ce_in ),      // 1-bit active high clock enable input for A input registers
        .CEB            ( ce_in ),      // 1-bit active high clock enable input for B input registers
        .CEC            ( 1'b0 ),       // 1-bit active high clock enable input for C input registers
        .CECARRYIN      ( 1'b0 ),       // 1-bit active high clock enable input for CARRYIN registers
        .CED            ( 1'b0 ),       // 1-bit active high clock enable input for D input registers
        .CEM            ( ce_m ),       // 1-bit active high clock enable input for multiplier registers
        .CEOPMODE       ( ce_ctrl ),    // 1-bit active high clock enable input for OPMODE registers
        .CEP            ( ce_p ),       // 1-bit active high clock enable input for P output registers
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

end else
`endif // XILINX

begin:GEN_GENERIC

    // Generic synthesizable multiplier

    // multiplier pipeline registers
    reg signed [17:0] a1_reg;
    reg signed [17:0] b1_reg;
    reg signed [35:0] m_reg;
    reg signed [47:0] p_reg;
    
    // post-adder input mux
    reg        [ 1:0] cs_reg;
    reg signed [47:0] mult_c;
    always @* begin
        case(cs_reg)
            C_ZERO:  mult_c = 48'd0;
            C_PREG:  mult_c = p_reg;
            C_PR17:  mult_c = { {17{p_reg[47]}}, p_reg[47:17] };
            default: mult_c = {48{1'bx}};
        endcase
    end

    always @(posedge clk) begin
        if(ce_in) begin
            // input registers
            a1_reg  <= mult_a;
            b1_reg  <= mult_b;
        end
        if(ce_ctrl) begin
            // control registers
            cs_reg  <= mult_c_sel;
        end
        if(ce_m) begin
            // multiplier
            m_reg   <= a1_reg * b1_reg;
        end
        if(ce_p) begin
            // post-addder
            p_reg   <= { {12{m_reg[35]}}, m_reg } + mult_c;
        end
    end

    // output
    assign p = p_reg;

end
endgenerate

endmodule

