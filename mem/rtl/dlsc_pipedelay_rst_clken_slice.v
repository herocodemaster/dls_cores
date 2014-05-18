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

module dlsc_pipedelay_rst_clken_slice #(
    parameter DELAY         = 1,            // delay from input to output (>= 1)
    parameter DATA          = 1,            // width of delayed data
    parameter RESET         = {DATA{1'b0}}  // reset value for data
) (
    input   wire                clk,
    input   wire                clk_en,
    input   wire                rst,

    input   wire    [DATA-1:0]  in_data,

    output  wire    [DATA-1:0]  out_data
);

`include "dlsc_synthesis.vh"

integer i;

wire [DATA-1:0] delay_data;

generate
if(DELAY>1) begin:GEN_DELAYN

    `DLSC_SHREG reg [DATA-1:0] mem[DELAY-2:0];

    always @(posedge clk) begin
        if(clk_en) begin
            for(i=(DELAY-2);i>=1;i=i-1) begin
                mem[i] <= mem[i-1];
            end
            mem[0] <= in_data;
        end
    end

    assign delay_data = mem[DELAY-2];

    `ifdef DLSC_SIMULATION
    `include "dlsc_sim_top.vh"

    reg rst_prev = 1'b0;
    reg mismatch;

    always @(posedge clk) begin
        if(!rst && rst_prev) begin
            mismatch = 1'b0;
            for(i=0;i<(DELAY-2);i=i+1) begin
                if(mem[i] != RESET) begin
                    mismatch = 1'b1;
                end
            end
            if(mismatch) begin
                `dlsc_warn("reset released before contents were entirely reset");
            end
        end
        rst_prev <= rst;
    end

    `include "dlsc_sim_bot.vh"
    `endif

end else begin:GEN_DELAY1

    assign delay_data = in_data;

end
endgenerate

`DLSC_PIPE_REG reg [DATA-1:0] out_data_r;

always @(posedge clk) begin
    if(rst) begin
        out_data_r  <= RESET;
    end else if(clk_en) begin
        out_data_r  <= delay_data;
    end
end

assign out_data = out_data_r;

endmodule

