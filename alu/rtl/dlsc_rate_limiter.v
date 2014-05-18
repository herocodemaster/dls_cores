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
// Limits the rate at which an input data stream is accepted. Useful if downstream
// modules can only accept data at a slower rate (and don't provide their own rate
// limiting function).

module dlsc_rate_limiter #(
    parameter CYCLES    = 1,    // limit data acceptance rate to 1 value every CYCLES clock cycles
    parameter UNIFORM   = 0     // force each accepted value to be an exact multiple of CYCLES apart
) (
    // system
    input   wire                        clk,
    input   wire                        rst,

    // throttle
    // in_ready will assert <= 1 cycle after stall is asserted
    input   wire                        stall,

    // input
    output  reg                         in_ready,
    input   wire                        in_valid
);

`include "dlsc_util.vh"

localparam CYCB = `dlsc_clog2(CYCLES);

generate
if(CYCLES>1) begin:GEN_LIMIT
    if(UNIFORM) begin:GEN_UNIFORM

        reg  [CYCB-1:0] cnt;
        wire            cnt_zero    = (cnt == 0);
        
        /* verilator lint_off WIDTH */
        always @(posedge clk) begin
            if(rst) begin
                in_ready    <= 1'b0;
                cnt         <= CYCLES-1;
            end else begin
                in_ready    <= cnt_zero && !stall;
                cnt         <= cnt_zero ? (CYCLES-1) : (cnt - 1);
            end
        end
        /* verilator lint_on WIDTH */

    end else begin:GEN_NONUNIFORM

        reg  [CYCB-1:0] cnt;
        wire            cnt_zero    = (cnt == 0);

        /* verilator lint_off WIDTH */
        always @(posedge clk) begin
            if(rst) begin
                in_ready    <= 1'b0;
                cnt         <= CYCLES-2;
            end else begin
                in_ready    <= cnt_zero && !stall;
                if(!cnt_zero) begin
                    cnt         <= cnt - 1;
                end
                if(in_ready && in_valid) begin
                    in_ready    <= 1'b0;
                    cnt         <= CYCLES-2;
                end
            end
        end
        /* verilator lint_on WIDTH */

    end
end else begin:GEN_NO_LIMIT

    always @(posedge clk) begin
        if(rst) begin
            in_ready    <= 1'b0;
        end else begin
            in_ready    <= !stall;
        end
    end

end
endgenerate

endmodule

