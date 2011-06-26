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
// Simple shallow FIFO. Uses dynamic shift-registers (found in most FPGAs)
// to simplify/reduce logic.

module dlsc_fifo_shiftreg #(
    parameter DATA          = 32,
    parameter DEPTH         = 16,
    parameter ALMOST_FULL   = 0,
    parameter ALMOST_EMPTY  = 0,
    parameter FULL_IN_RESET = 0     // indicate FIFO is full when in reset (could
                                    // be used to prevent pushes from blocks not
                                    // also held in reset)
) (
    // system
    input   wire                clk,
    input   wire                rst,

    // input
    input   wire                push_en,
    input   wire    [DATA-1:0]  push_data,

    // output
    input   wire                pop_en,
    output  wire    [DATA-1:0]  pop_data,

    // status
    output  reg                 empty,
    output  reg                 full,
    output  reg                 almost_empty,
    output  reg                 almost_full
);

`include "dlsc_clog2.vh"

localparam ADDR = `dlsc_clog2(DEPTH);

// read pointer
reg  [ADDR-1:0] addr;

always @(posedge clk) begin
    if(rst) begin
        addr        <= {ADDR{1'b1}}; // -1 when empty
    end else begin
        if( push_en && !pop_en) begin
            addr        <= addr + 1;
        end
        if(!push_en && pop_en) begin
            addr        <= addr - 1;
        end
    end
end

// shift-register for contents of FIFO
dlsc_shiftreg #(
    .DATA       ( DATA ),
    .ADDR       ( ADDR ),
    .DEPTH      ( DEPTH ),
    .WARNINGS   ( 0 )
) dlsc_shiftreg_inst (
    .clk        ( clk ),
    .write_en   ( push_en ),
    .write_data ( push_data ),
    .read_addr  ( addr ),
    .read_data  ( pop_data )
);

/* verilator lint_off WIDTH */

// flags
reg rst_done;
always @(posedge clk) begin
    if(rst) begin

        empty           <= 1'b1;
        almost_empty    <= 1'b1;

        full            <= ((FULL_IN_RESET>0)?1'b1:1'b0);
        almost_full     <= ((FULL_IN_RESET>0)?1'b1:1'b0);
        rst_done        <= ((FULL_IN_RESET>0)?1'b0:1'b1);

    end else begin

        if( push_en && !pop_en) begin

            empty           <= 1'b0;
            full            <= (addr == (DEPTH-2));

            if(addr == (      ALMOST_EMPTY-1) || (ALMOST_EMPTY  == 0    )) begin
                almost_empty    <= 1'b0;
            end

            if(addr == (DEPTH-ALMOST_FULL -2) || (ALMOST_FULL+1 == DEPTH)) begin
                almost_full     <= 1'b1;
            end

        end

        if(!push_en &&  pop_en) begin

            empty           <= (addr == 0);
            full            <= 1'b0;

            if(addr == (      ALMOST_EMPTY  )) begin
                almost_empty    <= 1'b1;
            end

            if(addr == (DEPTH-ALMOST_FULL -1)) begin
                almost_full     <= 1'b0;
            end

        end

        rst_done        <= 1'b1;
        if(!rst_done && FULL_IN_RESET>0) begin
            full            <= 1'b0;
            almost_full     <= 1'b0;
        end

    end
end

/* verilator lint_on WIDTH */


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @(posedge clk) begin

    if( push_en && !pop_en && full ) begin
        `dlsc_error("overflow");
    end
    if(             pop_en && empty) begin
        `dlsc_error("underflow");
    end

end

integer max_cnt;
always @(posedge clk) begin
    if(rst) begin
        max_cnt = 0;
    end else if(!empty && addr >= max_cnt) begin
        max_cnt = addr+1;
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

