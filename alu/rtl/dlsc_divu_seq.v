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
// Fully sequential (multi-cycle) unsigned integer divider.
// Computes 1 division every QB cycles.
// Delay from input to output is QB+2 cycles.

module dlsc_divu_seq #(
    parameter NB        = 8,    // bits for numerator/dividend
    parameter DB        = NB,   // bits for denominator/divisor
    parameter QB        = NB,   // bits for quotient
    parameter QSKIP     = 0     // MSbits of canonical quotient to skip
) (
    // system
    input   wire                    clk,

    // input
    // a new input can be submitted every QB cycles
    input   wire                    in_valid,
    input   wire    [NB-1:0]        in_num,
    input   wire    [DB-1:0]        in_den,

    // output
    // final result is available QB+2 cycles after in_valid
    output  wire    [QB-1:0]        out_quo
);

`include "dlsc_synthesis.vh"

localparam NDB  = NB + DB;

//    0 D D D D
// 0: 0 0 0 0 N N N N N N
// 1: 0 0 0 N N N N N N 0
// 2: 0 0 N N N N N N 0 0
// 3: 0 N N N N N N 0 0 0
// 4: N N N N N N 0 0 0 0
// 5: N N N N N 0 0 0 0 0
// 6: N N N N S 0 0 0 0 0
// 7: N N N S S 0 0 0 0 0
// 8: N N S S S 0 0 0 0 0
// 9: N S S S S 0 0 0 0 0

`DLSC_PIPE_REG  reg             c1_valid;

always @(posedge clk) begin
    c1_valid <= in_valid;
end

`DLSC_PIPE_REG  reg  [DB-1:0]   c1_den;             // denominator (constant for duration of division)

                wire [NDB-1:0]  c1_numl;            // latest numerator (is invalid if c1_selp is asserted)
`DLSC_PIPE_REG  reg  [NDB-1:0]  c1_nump;            // previous numerator

`DLSC_PIPE_REG  reg  [DB  :0]   c2_sub;

wire            c1_selp = (c1_valid || c2_sub[DB]); // use previous numerator instead of latest

wire [DB  :0]   c1_num  = ( c1_selp ? c1_nump[NB-1 +: DB+1] : c1_numl[NB-1 +: DB+1]);

always @(posedge clk) begin
    c2_sub <=  c1_num - {1'b0,c1_den};
end

assign          c1_numl = { c2_sub[DB-1:0] , c1_nump[NB-1:0] };

always @(posedge clk) begin
    case({in_valid,c1_selp})
        2'b00:   c1_nump <= c1_numl << 1;
        2'b01:   c1_nump <= c1_nump << 1;
        default: c1_nump <= { {DB{1'b0}} , in_num } << QSKIP;
    endcase
end

always @(posedge clk) begin
    if(in_valid) begin
        c1_den <= in_den;
    end
end

`DLSC_PIPE_REG  reg  [QB-1:0]   c3_quo;

always @(posedge clk) begin
    c3_quo <= { c3_quo[QB-2:0], !c2_sub[DB] };
end

assign out_quo = c3_quo;


// simulation checks

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

integer in_cnt;

always @(posedge clk) begin
    if(in_valid) begin
        if(in_cnt > 0) begin
            `dlsc_warn("division interrupted by new in_valid");
        end
        in_cnt  <= QB-1;
    end else if(in_cnt > 0) begin
        in_cnt  <= in_cnt - 1;
    end
end

`include "dlsc_sim_bot.vh"
`endif

endmodule

