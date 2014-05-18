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
// Config loading control logic for cfgrom. Automatically loads ROM contents
// once reset is released.

module dlsc_cfgrom_loader #(
    parameter DATA          = 8,            // bits for cfgrom data
    parameter ADDR          = 4,            // bits for cfgrom address (>= 1, even for DEPTH = 1)
    parameter DEPTH         = (2**ADDR),    // entries in cfgrom memory
    parameter SLICES        = 1,            // number of identically-sized cfgroms being configured by this module
    parameter FILL          = 0,            // fill value to use for unconfigured remainder (only used when CFG_LENGTH < DEPTH*SLICES)
    parameter CFG_DATA      = DATA,         // width of configuration stream (must be >= DATA)
    parameter CFG_LENGTH    = DEPTH*SLICES, // length of configuration stream consumed by this module (must be <= DEPTH*SLICES)
    parameter CFG_PAD       = 0             // configuration words to discard before actually configuring
) (
    // system
    input   wire                        clk,
    input   wire                        rst,

    // status
    output  reg                         done,

    // config stream input
    // stream must be reversed (starts at highest index and goes towards 0)
    output  reg                         in_ready,
    input   wire                        in_valid,
    input   wire    [CFG_DATA-1:0]      in_data,

    // config stream output
    input   wire                        out_ready,
    output  reg                         out_valid,
    output  reg     [CFG_DATA-1:0]      out_data,

    // config output to cfgrom
    output  reg                         cfg_en,
    output  reg     [SLICES-1:0]        cfg_wr_en,
    output  reg     [ADDR-1:0]          cfg_wr_addr,
    output  reg     [DATA-1:0]          cfg_wr_data
);

`include "dlsc_util.vh"

`dlsc_static_assert_lte( DEPTH, (2**ADDR) )
`dlsc_static_assert_lte( CFG_LENGTH, (DEPTH*SLICES) )
`dlsc_static_assert_gte( CFG_DATA, DATA )

localparam PADB             = `dlsc_clog2_lower(CFG_PAD,1);

localparam REM              = DEPTH*SLICES - CFG_LENGTH;

localparam INIT_DONE_SLICE  = CFG_LENGTH/DEPTH;
localparam INIT_DONE_ADDR   = CFG_LENGTH%DEPTH;

reg                 init_done;
reg                 pad_done;
reg                 en;

reg                 next_ready;
reg                 next_en;

always @* begin
    next_ready  = 1'b0;
    next_en     = 1'b0;
    if(!en && !in_ready) begin
        if(!init_done) begin
            next_en     = 1'b1;
        end else if(in_valid && !out_valid) begin
            next_ready  = 1'b1;
            if(pad_done && !done) begin
                next_en      = 1'b1;
            end
        end
    end
end

always @(posedge clk) begin
    if(rst) begin
        in_ready    <= 1'b0;
        en          <= 1'b0;
        out_valid   <= 1'b0;
    end else begin
        in_ready    <= next_ready;
        en          <= next_en;
        out_valid   <= (in_ready && done) || (out_valid && !out_ready);
    end
end

always @(posedge clk) begin
    if(in_ready) begin
        out_data    <= in_data;
    end
end

reg  [ADDR-1:0]     addr;
reg                 addr_last;

reg  [SLICES-1:0]   slice;  // one-hot

always @(posedge clk) begin
    if(rst) begin
        done        <= 1'b0;
        slice       <= 0;
        slice[SLICES-1] <= 1'b1;
    end else if(en && addr_last) begin
        slice       <= slice >> 1;
        if(slice[0]) begin
            done        <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    cfg_en      <= !done;
    cfg_wr_addr <= addr;
    cfg_wr_en   <= en ? slice : 0;
end

generate

if(DEPTH>1) begin:GEN_ADDR_DN

    /* verilator lint_off WIDTH */
    always @(posedge clk) begin
        if(rst) begin
            addr        <= DEPTH-1;
            addr_last   <= 1'b0;
        end else if(en) begin
            addr        <= addr - 1;
            addr_last   <= (addr == 1);
            if(addr_last) begin
                addr        <= DEPTH-1;
                addr_last   <= 1'b0;
            end
        end
    end
    /* verilator lint_on WIDTH */

end else begin:GEN_ADDR_D1

    always @(posedge clk) begin
        if(rst) begin
            addr        <= 0;
            addr_last   <= 1'b1;
        end
    end

end

if(REM>0) begin:GEN_DATA_REM

    /* verilator lint_off WIDTH */
    always @(posedge clk) begin
        if(rst) begin
            init_done   <= 1'b0;
        end else if(en && slice[INIT_DONE_SLICE] && (addr == INIT_DONE_ADDR)) begin
            init_done   <= 1'b1;
        end
    end
    /* verilator lint_on WIDTH */

    always @(posedge clk) begin
        if(rst) begin
            cfg_wr_data <= FILL;
        end else if(in_ready) begin
            cfg_wr_data <= in_data[DATA-1:0];
        end
    end

end else begin:GEN_DATA_NO_REM

    always @(posedge clk) begin
        if(rst) begin
            init_done   <= 1'b1;
        end
    end

    always @* begin
        cfg_wr_data = out_data[DATA-1:0];
    end

end

if(CFG_PAD>0) begin:GEN_PAD

    reg [PADB-1:0] cnt;

    always @(posedge clk) begin
        if(rst) begin
            /* verilator lint_off WIDTH */
            cnt         <= CFG_PAD-1;
            /* verilator lint_on WIDTH */
            pad_done    <= 1'b0;
        end else if(in_ready) begin
            cnt         <= cnt - 1;
            if(cnt == 0) begin
                pad_done    <= 1'b1;
            end
        end
    end

end else begin:GEN_NO_PAD
    
    always @(posedge clk) begin
        if(rst) begin
            pad_done    <= 1'b1;
        end
    end

end

endgenerate

endmodule

