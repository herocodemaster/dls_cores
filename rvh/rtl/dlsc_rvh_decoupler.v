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
// 2-level register slice for decoupling two ready/valid handshaked interfaces.
// All outputs are registered. No asynchronous paths exist between source and
// sink ports.

module dlsc_rvh_decoupler #(
    parameter WIDTH = 32
) (
    // system
    input   wire                clk,
    input   wire                rst,

    // source
    input   wire                in_en,          // clk_en for source
    output  reg                 in_ready,
    input   wire                in_valid,
    input   wire    [WIDTH-1:0] in_data,

    // sink
    input   wire                out_en,         // clk_en for sink
    input   wire                out_ready,
    output  reg                 out_valid,
    output  reg     [WIDTH-1:0] out_data
);

reg [WIDTH-1:0] data;       // valid value present when !in_ready
reg             rst_done;

always @(posedge clk) begin
    if(rst) begin
        in_ready        <= 1'b0;
        out_valid       <= 1'b0;
        out_data        <= {WIDTH{1'b0}};
        data            <= {WIDTH{1'b0}};
        rst_done        <= 1'b0;
    end else begin
        if(out_en && out_ready && out_valid) begin
            // sink consumed a value
            if(!in_ready) begin
                // valid data present in buffer
                // ..present to sink
                out_data        <= data;
                out_valid       <= 1'b1;
                // ..indicate to source that buffer space is now available
                in_ready        <= 1'b1;
            end else begin
                // out of data
                // (may be overriden below if source has more data)
                out_valid       <= 1'b0;
            end
        end

        if(in_en && in_ready && in_valid) begin
            // source supplied a value
            if(!out_valid || (out_en && out_ready)) begin
                // sink has no data
                // ..immediately present new value to sink
                out_data        <= in_data;
                out_valid       <= 1'b1;
            end else begin
                // save value in buffer
                data                <= in_data;
                // ..indicate buffer space no longer available
                in_ready            <= 1'b0;
            end
        end

        // logic for initially setting in_ready out of reset
        rst_done        <= 1'b1;
        if(!rst_done) begin
            in_ready        <= 1'b1;
        end
    end
end

endmodule

