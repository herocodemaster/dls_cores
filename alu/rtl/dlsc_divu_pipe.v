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
// Fully pipelined unsigned integer divider.
// Computes 1 division every cycle.
// Delay from input to output is QB+1 cycles.

module dlsc_divu_pipe #(
    parameter NB        = 8,    // bits for numerator/dividend
    parameter DB        = NB,   // bits for denominator/divisor
    parameter QB        = NB    // bits for quotient
) (
    // system
    input   wire                    clk,

    // input
    input   wire    [NB-1:0]        in_num,
    input   wire    [DB-1:0]        in_den,

    // output
    // final result is available QB+2 cycles after in_valid
    output  wire    [QB-1:0]        out_quo
);

`include "dlsc_util.vh"
`include "dlsc_synthesis.vh"

localparam NDB  = NB + DB;

genvar j;

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

wire [DB -1:0]  stg_den [QB:0];
wire [NDB-1:0]  stg_numl[QB:0];
wire [NDB-1:0]  stg_nump[QB:0];
wire [QB   :0]  stg_selp;

// drive inputs
assign stg_den [0]  = in_den;
assign stg_numl[0]  = 0;
assign stg_nump[0]  = { {DB{1'b0}} , in_num };
assign stg_selp[0]  = 1'b1;

wire [QB-1:0]  stg_quo_n;

generate
for(j=0;j<QB;j=j+1) begin:GEN_STAGES

    `DLSC_PIPE_REG reg [DB -1:0] den;
    `DLSC_PIPE_REG reg [DB   :0] sub;
    `DLSC_PIPE_REG reg [NDB-1:0] nump;

    always @(posedge clk) begin
        den     <= stg_den[j];
        sub     <= ( stg_selp[j] ? stg_nump[j][NB-1 +: DB+1] : stg_numl[j][NB-1 +: DB+1] ) - {1'b0,stg_den[j]};
        nump    <= ( stg_selp[j] ? stg_nump[j]               : stg_numl[j]               ) << 1;
    end

    reg [NDB:0] numlo;
    reg [NDB:0] numpo;

    always @* begin
        numlo = { 1'b0, sub[DB-1:0], nump[NB-1:0] };
        numpo = { 1'b0, nump };
        // mask off bits that should always be 0 (should help optimizer remove unneeded registers)
        numlo[`dlsc_min(NB-1,j):0] = 0;
        numpo[`dlsc_min(NB-1,j):0] = 0;
        numlo[NDB:`dlsc_min(NDB,NB+1+j)] = 0;
        numpo[NDB:`dlsc_min(NDB,NB+1+j)] = 0;
    end

    assign stg_den [j+1] = den;
    assign stg_selp[j+1] = sub[DB];
    assign stg_numl[j+1] = numlo[NDB-1:0];
    assign stg_nump[j+1] = numpo[NDB-1:0];

    if((j%2) == 1) begin:GEN_DELAY_ODD
        // delay 2 bits at a time (to take advantage of dual SRL16 in 1 LUT)

        // delay even (previous one) by 1 more to align with odd (this one)
        `DLSC_PIPE_REG reg selp_del;
        always @(posedge clk) begin
            selp_del <= stg_selp[j];
        end

        // delay even+odd
        dlsc_pipedelay #(
            .DATA       ( 2 ),
            .DELAY      ( QB-1-j )
        ) dlsc_pipedelay (
            .clk        ( clk ),
            .in_data    ( { stg_selp[j+1], selp_del } ),
            .out_data   ( stg_quo_n[j:j-1] )
        );
    end else if(j == (QB-1)) begin:GEN_DELAY_LAST
        // no delay needed on last stage
        assign stg_quo_n[j] = stg_selp[j+1];
    end

end
endgenerate

// reverse output (stage 0 produces MSbit)

wire [QB-1:0] stg_quo_n_rev;

generate
for(j=0;j<QB;j=j+1) begin:GEN_QUO_N_REV
    assign stg_quo_n_rev[j] = stg_quo_n[QB-1-j];
end
endgenerate

// invert and register output

`DLSC_PIPE_REG reg [QB-1:0] out_quo_r;
assign out_quo = out_quo_r;

always @(posedge clk) begin
    out_quo_r <= ~stg_quo_n_rev;
end

endmodule

