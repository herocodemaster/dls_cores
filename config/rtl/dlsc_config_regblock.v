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
// Register block memory. Designed to work with config_enabler. Produces config
// stream output for consumption by cfgreg_loader and cfgrom_loader.

module dlsc_config_regblock #(
    parameter DATA              = 32,           // width of register block
    parameter DEPTH             = 16,           // depth of register block
    parameter BASE              = 0,            // base address of register block (word address, not byte)
    parameter ADDR              = 8,            // bits for command word address (must be enough for BASE+DEPTH)
    parameter BRAM              = (DEPTH > 64)  // use block RAM (instead of LUT RAM)
) (
    // system
    input   wire                        clk,
    input   wire                        rst,
    input   wire                        rst_cfg,

    // control
    input   wire                        control_enable,

    // config handshake
    output  reg                         config_valid,
    input   wire                        config_ready,

    // submit input
    input   wire                        config_submit,

    // status
    output  reg                         config_empty,
    output  reg                         done,

    // error output
    output  reg                         set_config_error,

    // write interface
    // write response must be generated at higher level
    input   wire                        csr_cmd_valid,
    input   wire                        csr_cmd_write,
    input   wire    [ADDR-1:0]          csr_cmd_addr,       // word address, not byte
    input   wire    [31:0]              csr_cmd_data,

    // config stream output
    input   wire                        out_ready,
    output  reg                         out_valid,
    output  wire    [DATA-1:0]          out_data
);

`include "dlsc_util.vh"
`include "dlsc_synthesis.vh"

localparam DB = `dlsc_clog2(DEPTH);

/* verilator lint_off WIDTH */
wire            cmd_sel         = (csr_cmd_addr >= BASE && csr_cmd_addr < (BASE+DEPTH));
wire [ADDR-1:0] addr_base       = BASE;
/* verilator lint_on WIDTH */

wire            mem_wr_en_pre   = csr_cmd_valid && csr_cmd_write && cmd_sel;

reg             mem_wr_en;
reg  [DB-1:0]   mem_wr_addr;
wire [DATA-1:0] mem_wr_data     = csr_cmd_data[DATA-1:0];

always @(posedge clk) begin
    mem_wr_en   <= mem_wr_en_pre && !config_valid;
    mem_wr_addr <= csr_cmd_addr[DB-1:0] - addr_base[DB-1:0];
end

reg next_config_error;
reg next_config_valid;

always @* begin
    next_config_error = 1'b0;
    next_config_valid = config_valid && !config_ready;
    if(control_enable) begin
        if(config_valid) begin
            if(config_submit) begin
                // can't double-submit
                next_config_error = 1'b1;
            end
            if(mem_wr_en_pre) begin
                // can't write to memory until previously-submitted config is used
                next_config_error = 1'b1;
            end
        end else begin
            if(config_submit) begin
                next_config_valid = 1'b1;
            end
        end
    end else begin
        next_config_valid = 1'b0;
        if(config_submit) begin
            // can't submit when disabled
            next_config_error = 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(rst) begin
        set_config_error    <= 1'b0;
        config_valid        <= 1'b0;
        config_empty        <= 1'b0;
    end else begin
        set_config_error    <= next_config_error;
        config_valid        <= next_config_valid;
        config_empty        <= !next_config_valid && control_enable; // can only be empty when actually enabled
    end
end

wire            mem_rd_en       = !rst_cfg && !out_valid && !done;
reg  [DB-1:0]   mem_rd_addr;

/* verilator lint_off WIDTH */
wire            mem_rd_last     = (mem_rd_addr == (DEPTH-1));
/* verilator lint_on WIDTH */

always @(posedge clk) begin
    if(rst_cfg) begin
        out_valid   <= 1'b0;
    end else begin
        out_valid   <= (out_valid && !out_ready) || mem_rd_en;
    end
end

always @(posedge clk) begin
    if(rst_cfg) begin
        mem_rd_addr <= 0;
        done        <= 1'b0;
    end else if(out_ready && out_valid) begin
        mem_rd_addr <= mem_rd_addr + 1;
        if(mem_rd_last) begin
            done        <= 1'b1;
        end
    end
end

generate
if(BRAM) begin:GEN_BRAM

    dlsc_ram_dp #(
        .DATA           ( DATA ),
        .ADDR           ( DB ),
        .DEPTH          ( DEPTH ),
        .PIPELINE_WR    ( 0 ),
        .PIPELINE_RD    ( 1 )
    ) dlsc_ram_dp (
        .write_clk      ( clk ),
        .write_en       ( mem_wr_en ),
        .write_addr     ( mem_wr_addr ),
        .write_data     ( mem_wr_data ),
        .read_clk       ( clk ),
        .read_en        ( mem_rd_en ),
        .read_addr      ( mem_rd_addr ),
        .read_data      ( out_data )
    );

end else begin:GEN_LUTRAM

    `DLSC_LUTRAM reg [DATA-1:0] mem [DEPTH-1:0];

    wire [DB-1:0]   mem_addr = mem_wr_en ? mem_wr_addr : mem_rd_addr;

    reg  [DATA-1:0] out_data_r;

    always @(posedge clk) begin
        out_data_r <= mem[mem_addr];
        if(mem_wr_en) begin
            mem[mem_addr] <= mem_wr_data;
        end
    end

    assign out_data = out_data_r;

end
endgenerate

endmodule

