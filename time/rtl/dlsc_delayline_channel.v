// 
// Copyright (c) 2012, Daniel Strother < http://danstrother.com/ >
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
// Delay-line channel.

module dlsc_delayline_channel #(
    parameter DATA              = 1,                    // width of data to be delayed
    parameter INERTIAL          = 0,                    // use inertial rather than transport delay
    parameter DELAY             = 32,                   // maximum delay
    parameter DB                = 5                     // bits to select delay
) (
    // system
    input   wire                    clk,

    // timebase
    input   wire                    clk_en,

    // config
    input   wire                    cfg_bypass,
    input   wire    [DB-1:0]        cfg_delay,

    // input
    input   wire    [DATA-1:0]      in_data,

    // delayed output
    output  wire    [DATA-1:0]      out_data
);

generate
if(!INERTIAL) begin:GEN_TRANSPORT

    // Transport Delay; a genuine delay-line

    dlsc_shiftreg #(
        .DATA       ( DATA ),
        .ADDR       ( DB ),
        .DEPTH      ( DELAY )
    ) dlsc_shiftreg (
        .clk        ( clk ),
        .write_en   ( clk_en || cfg_bypass ),
        .write_data ( in_data ),
        .read_addr  ( cfg_delay ),
        .read_data  ( out_data )
    );

end else begin:GEN_INERTIAL

    // Inertial Delay; input only makes it to output if it remains unchanged for
    // the entire duration of the delay.

    reg  [DATA-1:0] prev_data;

    always @(posedge clk) begin
        prev_data   <= in_data;
    end

    wire            change      = (prev_data != in_data);

    reg  [DB-1:0]   cnt;
    wire            cnt_lim     = (cnt == 0);

    always @(posedge clk) begin
        if(cfg_bypass || change) begin
            cnt     <= cfg_delay;
        end else if(clk_en && !cnt_lim) begin
            cnt     <= cnt - 1;
        end
    end

    reg  [DATA-1:0] out_data_r;
    assign          out_data    = out_data_r;

    always @(posedge clk) begin
        if(cfg_bypass || (!change && clk_en && cnt_lim)) begin
            out_data_r  <= in_data;
        end
    end
end
endgenerate

endmodule

