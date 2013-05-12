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
// Implements an arbitrary parameterized pipeline delay. Infers efficient
// shift-registers where possible.

module dlsc_pipedelay #(
    parameter DATA      = 32,
    parameter DELAY     = 1,
    parameter FANOUT    = 0     // Set if output of module drives a high fanout net.
) (
    input   wire                clk,

    input   wire    [DATA-1:0]  in_data,

    output  wire    [DATA-1:0]  out_data
);

`include "dlsc_synthesis.vh"

generate
    integer i;
    genvar j;

    if(DELAY == 0) begin:GEN_DELAY0

        assign out_data     = in_data;

    end else if(DELAY == 1) begin:GEN_DELAY1

        if(FANOUT) begin:GEN_FANOUT

            `DLSC_FANOUT_REG reg [DATA-1:0] out_data_r0;
            always @(posedge clk) begin
                out_data_r0 <= in_data;
            end
            assign out_data  = out_data_r0;

        end else begin:GEN_NORMAL

            reg [DATA-1:0] out_data_r0;
            always @(posedge clk) begin
                out_data_r0 <= in_data;
            end
            assign out_data  = out_data_r0;

        end

    end else begin:GEN_DELAYN

        if(FANOUT) begin:GEN_FANOUT

            reg [DATA-1:0] mem[DELAY-2:0];
            `DLSC_FANOUT_REG reg [DATA-1:0] out_data_r;
            always @(posedge clk) begin
                out_data_r  <= mem[DELAY-2];
                for(i=(DELAY-2);i>=1;i=i-1) begin
                    mem[i]      <= mem[i-1];
                end
                mem[0]      <= in_data;
            end
            assign out_data = out_data_r;

        end else begin:GEN_NORMAL

            reg [DATA-1:0] mem[DELAY-2:0];
            reg [DATA-1:0] out_data_r;
            always @(posedge clk) begin
                out_data_r  <= mem[DELAY-2];
                for(i=(DELAY-2);i>=1;i=i-1) begin
                    mem[i]      <= mem[i-1];
                end
                mem[0]      <= in_data;
            end
            assign out_data = out_data_r;

        end

    end
endgenerate

endmodule
    
