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
// Asynchronous domain crossing for data-path of dlsc_domaincross.
// Does NOT have synchronizer flops; instead, relies on sampling flop
// only being enabled after input data has stabilized.

module dlsc_domaincross_slice #(
    parameter RESET = 1'b0
) (
    // input
    input   wire    in_clk,
    input   wire    in_rst,
    input   wire    in_en,
    input   wire    in_data,

    // output
    input   wire    out_clk,
    input   wire    out_rst,
    input   wire    out_en,
    output  wire    out_data
);

//(* IOB="FALSE", SHIFT_EXTRACT="NO", MAXDELAY="1ns" *) reg in_reg;
(* IOB="FALSE", SHIFT_EXTRACT="NO" *) reg in_reg;

always @(posedge in_clk) begin
    if(in_rst) begin
        in_reg  <= RESET;
    end else if(in_en) begin
        in_reg  <= in_data;
    end
end

(* IOB="FALSE", SHIFT_EXTRACT="NO" *) reg out_reg;

always @(posedge out_clk) begin
    if(out_rst) begin
        out_reg <= RESET;
    end else if(out_en) begin
        out_reg <= in_reg;
    end
end

assign out_data = out_reg;


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @* begin
    if(!out_rst && in_en && out_en) begin
        `dlsc_error("in_en and out_en must never be asserted simultaneously");
    end
end

reg in_reg_prev;
reg out_rst_prev;
always @(posedge out_clk) begin
    in_reg_prev <= in_reg;
    out_rst_prev <= out_rst;
    if(!out_rst && out_en && in_reg_prev != in_reg) begin
        `dlsc_error("in_reg must be stable when out_en is asserted");
    end
    if(!out_rst && out_rst_prev && (in_reg != RESET || in_reg_prev != RESET)) begin
        `dlsc_error("in_reg must be stable at RESET (%0x) when out_rst is deasserted", RESET);
    end
end

`include "dlsc_sim_bot.vh"
`endif


endmodule

