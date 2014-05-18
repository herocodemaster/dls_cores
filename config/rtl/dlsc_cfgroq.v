// 
// Copyright (c) 2014, Daniel Strother < http://danstrother.com/ >
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
// Configurable Read-Only-Queue. Can be reconfigured prior to use.
// Wrapper for dlsc_cfgrom. Use dlsc_cfgrom_loader to configure.

module dlsc_cfgroq #(
    parameter DATA          = 4,            // bits for data
    parameter ADDR          = 4,            // bits for address
    parameter DEPTH         = (2**ADDR)     // entries in memory
) (
    // system
    input   wire                        clk,

    // config
    // memory must be populated by writing sequentially from back to front
    input   wire                        cfg_en,         // assert for entire duration of config operation
    input   wire                        cfg_wr_en,
    input   wire    [ADDR-1:0]          cfg_wr_addr,
    input   wire    [DATA-1:0]          cfg_wr_data,

    // FIFO read port
    input   wire                        rd_rst,
    input   wire                        rd_pop,
    output  wire                        rd_empty,
    output  wire    [DATA-1:0]          rd_data
);

reg  [ADDR-1:0] addr;
reg             empty;

reg  [ADDR-1:0] next_addr;
reg             next_empty;

always @* begin
    next_addr   = addr;
    next_empty  = empty;
    if(rd_pop) begin
        next_addr   = addr + 1;
        /* verilator lint_off WIDTH */
        next_empty  = (addr == (DEPTH-1));
        /* verilator lint_on WIDTH */
    end
    if(rd_rst) begin
        next_addr   = 0;
        next_empty  = 1'b0;
    end
end

always @(posedge clk) begin
    addr    <= next_addr;
    empty   <= next_empty;
end

assign rd_empty = empty;

dlsc_cfgrom #(
    .DATA           ( DATA ),
    .ADDR           ( ADDR ),
    .DEPTH          ( DEPTH ),
    .PIPELINE       ( 1 )
) dlsc_cfgrom (
    .clk            ( clk ),
    .cfg_en         ( cfg_en ),
    .cfg_wr_en      ( cfg_wr_en ),
    .cfg_wr_addr    ( cfg_wr_addr ),
    .cfg_wr_data    ( cfg_wr_data ),
    .in_rst         ( 1'b0 ),
    .in_addr        ( next_addr ),
    .out_data       ( rd_data )
);

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

reg first_pop = 1'b1;

always @(posedge clk) begin
    if(cfg_en) begin
        first_pop <= 1'b1;
    end else if(rd_rst) begin
    end else if(rd_pop) begin
        first_pop <= 1'b0;
        if(first_pop && addr != 0) begin
            `dlsc_error("rd_rst not asserted prior to first pop");
        end
        if(rd_empty) begin
            `dlsc_error("underflow");
        end
    end
end

`include "dlsc_sim_bot.vh"
`endif

endmodule

