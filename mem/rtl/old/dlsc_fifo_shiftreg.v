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
// Shallow FIFO with ready/valid handshakes. Uses dynamic shift-registers
// (found in most FPGAs) to simplify/reduce logic.

module dlsc_fifo_shiftreg #(
    parameter DATA          = 32,
    parameter DEPTH         = 16,
    parameter ALMOST_EMPTY  = DEPTH/2,
    parameter ALMOST_FULL   = DEPTH/2
) (
    input   wire                clk,
    input   wire                rst,

    // status
    output  reg                 empty,
    output  reg                 full,
    output  reg                 almost_empty,
    output  reg                 almost_full,

    // write/push port
    input   wire                write_en,       // clock enable for write port
    output  reg                 write_ready,
    input   wire                write_valid,
    input   wire    [DATA-1:0]  write_data,

    // read/pop port
    input   wire                read_en,        // clock enable for read port
    input   wire                read_ready,
    output  reg                 read_valid,
    output  wire    [DATA-1:0]  read_data
);

`include "dlsc_clog2.vh"
localparam DEPTH_BITS = (DEPTH>1) ? `dlsc_clog2(DEPTH) : 1;

wire do_write   = write_en && write_ready && write_valid;
wire do_read    = read_en && read_ready && read_valid;

reg [DEPTH_BITS-1:0] addr;

wire addr_clk_en = ( do_write != do_read );
always @(posedge clk) begin
    if(rst) begin
        addr            <= {DEPTH_BITS{1'b1}};
    end else if(addr_clk_en) begin
        addr            <= do_write ? (addr + 1) : (addr - 1);
    end
end

always @(posedge clk) begin
    if(rst) begin
        empty           <= 1'b1;
        full            <= 1'b0;
        almost_empty    <= 1'b1;
        almost_full     <= (ALMOST_FULL==DEPTH);
        write_ready     <= 1'b0;
        read_valid      <= 1'b0;
    end else begin

        // a write
        if(do_write && !do_read) begin
            empty           <= 1'b0;
            read_valid      <= 1'b1;
/* verilator lint_off WIDTH */
            full            <= ((DEPTH==1) || addr == (DEPTH-2));
            write_ready     <= !((DEPTH==1) || addr == (DEPTH-2));
            if(addr == (DEPTH-ALMOST_FULL-2)) begin
                almost_full     <= 1'b1;
            end
            if(addr == ALMOST_EMPTY-1) begin
                almost_empty    <= 1'b0;
            end
/* verilator lint_on WIDTH */
        end

        // a read
        if(!do_write && do_read) begin
            empty           <= (addr == 0);
            read_valid      <= !(addr == 0);
            full            <= 1'b0;
            write_ready     <= 1'b1;
/* verilator lint_off WIDTH */
            if(addr == ALMOST_EMPTY) begin
                almost_empty    <= 1'b1;
            end
            if(addr == (DEPTH-ALMOST_FULL-1)) begin
                almost_full     <= 1'b0;
            end
/* verilator lint_on WIDTH */
        end

        // simultaneous read/write doesn't change any status

        // set write_ready after reset
        if(!full && !write_ready)
            write_ready     <= 1'b1;
    end
end

// shift-register for storing contents of FIFO
dlsc_shiftreg #(
    .DATA       ( DATA ),
    .ADDR       ( DEPTH_BITS ),
    .DEPTH      ( DEPTH ),
    .WARNINGS   ( 0 )
) dlsc_shiftreg_inst (
    .clk        ( clk ),
    .write_en   ( do_write ),
    .write_data ( write_data ),
    .read_addr  ( addr ),
    .read_data  ( read_data )
);

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"
integer max_cnt;
always @(posedge clk) begin
    if(rst) begin
        max_cnt     <= 0;
    end else begin
        if(!empty && addr >= max_cnt) begin
            max_cnt     <= addr+1;
        end
    end
end

task report;
begin
    `dlsc_info("max usage: %0d%% (%0d/%0d)",((max_cnt*100)/DEPTH),max_cnt,DEPTH);
end
endtask
`include "dlsc_sim_bot.vh"
`endif

endmodule

