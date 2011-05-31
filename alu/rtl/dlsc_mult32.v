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

module dlsc_mult32 (
    input   wire                clk,

    input   wire    [31:0]      in0,
    input   wire    [31:0]      in1,
    
    input   wire                sign,
    input   wire                start,

    output  reg     [63:0]      out,
    output  reg                 done
);

// save inputs when started
reg signed [17:0]  in0_lo;
reg signed [17:0]  in0_hi;
reg signed [17:0]  in1_lo;
reg signed [17:0]  in1_hi;

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
reg [2:0] cnt;

reg mult_a_sel;
reg mult_b_sel;
reg [1:0] mult_c_sel;

localparam C_ZERO   = 2'b00,
           C_PREG   = 2'b10,
           C_PR17   = 2'b11;

reg [2:0] out_en;

always @(posedge clk) begin
    if(start) begin

        cnt         <= 0;

        mult_a_sel  <= 1'b0;
        mult_b_sel  <= 1'b0;
        mult_c_sel  <= C_ZERO;

        out_en      <= 3'h0;

        done        <= 1'b0;

    end else begin

        cnt         <= cnt + 1;
        
        mult_a_sel  <= 1'b0;
        mult_b_sel  <= 1'b0;
        mult_c_sel  <= C_ZERO;

        out_en      <= 3'h0;

        done        <= 1'b0;

        case(cnt)

            0: begin
                // 1st applied to inputs
                mult_a_sel  <= 1'b1;
                mult_b_sel  <= 1'b0;
            end
            1: begin
                // 2nd applied to inputs
                // 1st through a1/b1 reg
                mult_a_sel  <= 1'b0;
                mult_b_sel  <= 1'b1;
                mult_c_sel  <= C_ZERO;
            end
            2: begin
                // 3rd applied to inputs
                // 2nd through a1/b1 reg
                // 1st through mreg
                mult_a_sel  <= 1'b1;
                mult_b_sel  <= 1'b1;
                mult_c_sel  <= C_PR17;
                out_en[0]   <= 1'b1;
            end
            3: begin
                // 4th applied to inputs
                // 3rd through a1/b1 reg
                // 2nd through mreg
                // 1st through preg
                mult_c_sel  <= C_PREG;
            end
            4: begin    
                // 4th through a1/b1 reg
                // 3rd through mreg
                // 2nd through preg
                // 1st through output
                mult_c_sel  <= C_PR17;
                out_en[1]   <= 1'b1;
            end
            5: begin
                // 4th through mreg
                // 3rd through preg
                // 2nd through output
                // 1st through output
                out_en[2]   <= 1'b1;
            end
            6: begin
                // 4th through preg
                // 3rd through output
                // 2nd through output
                // 1st through output
                done        <= 1'b1;
                cnt         <= cnt;
            end

        endcase

    end
end


// multipler inputs
wire signed [17:0]  mult_a;
wire signed [17:0]  mult_b;
reg  signed [47:0]  mult_c;

// multiplier
reg signed [17:0] a1_reg;
reg signed [17:0] b1_reg;
reg signed [35:0] m_reg;
reg signed [47:0] p_reg;

assign mult_a = mult_a_sel ? in0_hi : in0_lo;
assign mult_b = mult_b_sel ? in1_hi : in1_lo;

always @* begin
    case(mult_c_sel)
        C_PREG:  mult_c = p_reg;
        C_PR17:  mult_c = { {17{p_reg[47]}}, p_reg[47:17] };
        default: mult_c = 48'd0;
    endcase
end

always @(posedge clk) begin
    // input registers
    a1_reg  <= mult_a;
    b1_reg  <= mult_b;

    // multiplier
    m_reg   <= a1_reg * b1_reg;

    // post-addder
    p_reg   <= { {12{m_reg[35]}}, m_reg } + mult_c;
end

// output
always @(posedge clk) if(out_en[0]) out[16: 0] <= p_reg[16:0];
always @(posedge clk) if(out_en[1]) out[33:17] <= p_reg[16:0];
always @(posedge clk) if(out_en[2]) out[63:34] <= p_reg[29:0];


endmodule

