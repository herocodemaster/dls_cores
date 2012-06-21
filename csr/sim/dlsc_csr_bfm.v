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
// BFM master for CSR bus.

module dlsc_csr_bfm #(
    parameter ADDR  = 32,
    parameter DATA  = 32
) (
    // System
    input   wire                    clk,
    input   wire                    rst,

    // CSR Command
    output  reg                     csr_cmd_valid,
    output  reg                     csr_cmd_write,
    output  reg     [ADDR-1:0]      csr_cmd_addr,
    output  reg     [DATA-1:0]      csr_cmd_data,

    // CSR Response
    input   wire                    csr_rsp_valid,
    input   wire                    csr_rsp_error,
    input   wire    [DATA-1:0]      csr_rsp_data
);

`include "dlsc_sim_top.vh"

initial begin
    csr_cmd_valid   <= 1'b0;
    csr_cmd_write   <= 1'bx;
    csr_cmd_addr    <= {ADDR{1'bx}};
    csr_cmd_data    <= {DATA{1'bx}};
end

task read;
    input [ADDR-1:0] addr;
    output [DATA-1:0] data;
begin
    // not initially synchronizing to clock, so back-to-back transactions are possible
    if(!clk) begin
        `dlsc_warn("not synchronized to clock");
    end
    // assert command
    csr_cmd_valid   <= 1'b1;
    csr_cmd_write   <= 1'b0;
    csr_cmd_addr    <= addr;
    csr_cmd_data    <= {DATA{1'bx}};
    @(posedge clk);
    // de-assert command
    csr_cmd_valid   <= 1'b0;
    csr_cmd_write   <= 1'bx;
    csr_cmd_addr    <= {ADDR{1'bx}};
    csr_cmd_data    <= {DATA{1'bx}};
    // wait for response
    while(!csr_rsp_valid) @(posedge clk);
    if(csr_rsp_error) begin
        `dlsc_warn("got rsp_error on read");
        data        = {DATA{1'bx}};
    end else begin
        data        = csr_rsp_data;
    end
end
endtask

task write;
    input [ADDR-1:0] addr;
    input [DATA-1:0] data;
begin
    // not initially synchronizing to clock, so back-to-back transactions are possible
    if(!clk) begin
        `dlsc_warn("not synchronized to clock");
    end
    // assert command
    csr_cmd_valid   <= 1'b1;
    csr_cmd_write   <= 1'b1;
    csr_cmd_addr    <= addr;
    csr_cmd_data    <= data;
    @(posedge clk);
    // de-assert command
    csr_cmd_valid   <= 1'b0;
    csr_cmd_write   <= 1'bx;
    csr_cmd_addr    <= {ADDR{1'bx}};
    csr_cmd_data    <= {DATA{1'bx}};
    // wait for response
    while(!csr_rsp_valid) @(posedge clk);
    if(csr_rsp_error) begin
        `dlsc_warn("got rsp_error on write");
    end
end
endtask

always @(negedge csr_rsp_valid) begin
    #0;
    if(csr_rsp_error !== 1'b0) begin
        `dlsc_error("rsp_error should idle low");
    end
    if(csr_rsp_data !== {DATA{1'b0}}) begin
        `dlsc_error("rsp_data should idle low");
    end
end

`include "dlsc_sim_bot.vh"

endmodule


