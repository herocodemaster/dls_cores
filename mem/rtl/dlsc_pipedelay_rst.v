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
// Similar to dlsc_pipedelay, but allows for resetting of contents. Does NOT
// infer shift-registers in most FPGAs, and should only be used where a reset
// is absolutely required (control-path, not data-path).

module dlsc_pipedelay_rst #(
    parameter DATA      = 32,
    parameter DELAY     = 1,
    parameter RESET     = {DATA{1'b0}}
) (
    input   wire                clk,
    input   wire                rst,

    input   wire    [DATA-1:0]  in_data,

    output  wire    [DATA-1:0]  out_data
);

`include "dlsc_clog2.vh"
localparam DELAYN           = (DELAY>1) ? DELAY : 2;

generate
    if(DELAY == 0) begin:GEN_DELAY0

        assign out_data     = in_data;

    end else if(DELAY == 1) begin:GEN_DELAY1

        reg [DATA-1:0] out_data_r0;

        always @(posedge clk) begin
            if(rst) begin
                out_data_r0     <= RESET;
            end else begin
                out_data_r0     <= in_data;
            end
        end
        assign out_data = out_data_r0;

    end else begin:GEN_DELAYN

        integer i;
        
        reg [DATA-1:0] out_data_r [DELAYN-2:0];
        reg [DATA-1:0] out_data_rn;

        always @(posedge clk) begin
            if(rst) begin
                out_data_rn     <= RESET;
                for(i=(DELAYN-2);i>=0;i=i-1) begin
                    out_data_r[i]   = RESET;
                end
            end else begin
                out_data_rn     <= out_data_r[DELAYN-2];
                
                for(i=(DELAYN-2);i>0;i=i-1) begin
                    out_data_r[i]   = out_data_r[i-1];
                end
                out_data_r[0]   = in_data;
                    
            end
        end
        assign out_data = out_data_rn;

    end
endgenerate

endmodule
    
