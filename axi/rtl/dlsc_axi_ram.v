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
// Block RAM with AXI interface

module dlsc_axi_ram #(
    parameter SIZE          = 8192,     // RAM size in bytes
    // AXI parameters
    parameter DATA          = 32,
    parameter ADDR          = 32,
    parameter LEN           = 4,
    // derived; don't touch
    parameter STRB          = (DATA/8)
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // ** AXI **

    // read command
    output  wire                    axi_ar_ready,
    input   wire                    axi_ar_valid,
    input   wire    [ADDR-1:0]      axi_ar_addr,
    input   wire    [LEN-1:0]       axi_ar_len,

    // read data/response
    input   wire                    axi_r_ready,
    output  reg                     axi_r_valid,
    output  reg                     axi_r_last,
    output  wire    [DATA-1:0]      axi_r_data,
    output  wire    [1:0]           axi_r_resp,

    // write command
    output  wire                    axi_aw_ready,
    input   wire                    axi_aw_valid,
    input   wire    [ADDR-1:0]      axi_aw_addr,
    input   wire    [LEN-1:0]       axi_aw_len,

    // write data
    output  wire                    axi_w_ready,
    input   wire                    axi_w_valid,
    input   wire                    axi_w_last,
    input   wire    [DATA-1:0]      axi_w_data,
    input   wire    [STRB-1:0]      axi_w_strb,

    // write response
    input   wire                    axi_b_ready,
    output  reg                     axi_b_valid,
    output  wire    [1:0]           axi_b_resp
);

`include "dlsc_clog2.vh"

localparam RAM_DEPTH    = ((SIZE+STRB-1)/STRB);
localparam RAM_ADDR     = `dlsc_clog2(RAM_DEPTH);

localparam LSB          = `dlsc_clog2(STRB);
localparam INC_MSB      = ((RAM_ADDR+LSB)>12) ? (12-LSB) : (RAM_ADDR);  // only increment within a 4K region

// ** RAM **

wire    [STRB-1:0]      wr_en;
reg     [RAM_ADDR-1:0]  wr_addr;
wire    [DATA-1:0]      wr_data;

wire                    rd_en;
reg     [RAM_ADDR-1:0]  rd_addr;
wire    [DATA-1:0]      rd_data;

genvar j;
generate
for(j=0;j<STRB;j=j+1) begin:GEN_RAMS
    dlsc_ram_dp #(
        .DATA           ( 8 ),
        .ADDR           ( RAM_ADDR ),
        .DEPTH          ( RAM_DEPTH ),
        .PIPELINE_WR    ( 0 ),
        .PIPELINE_RD    ( 1 ),
        .WARNINGS       ( 0 )
    ) dlsc_ram_dp (
        .write_clk      ( clk ),
        .write_en       ( wr_en[j] ),
        .write_addr     ( wr_addr ),
        .write_data     ( wr_data[ j*8 +: 8] ),
        .read_clk       ( clk ),
        .read_en        ( rd_en ),
        .read_addr      ( rd_addr ),
        .read_data      ( rd_data[ j*8 +: 8] )
    );
end
endgenerate

// ** Write **

// write command

reg                     wr_active;

always @(posedge clk) begin
    if(rst) begin
        wr_active       <= 1'b0;
    end else begin
        if(axi_w_ready && axi_w_valid && axi_w_last) begin
            wr_active       <= 1'b0;
        end
        if(axi_aw_ready && axi_aw_valid) begin
            wr_active       <= 1'b1;
        end
    end
end

assign                  axi_aw_ready    = !wr_active || (axi_w_ready && axi_w_valid && axi_w_last);

always @(posedge clk) begin
    if(axi_aw_ready && axi_aw_valid) begin
        wr_addr         <= axi_aw_addr[ LSB +: RAM_ADDR ];
    end
    if(axi_w_ready && axi_w_valid && !axi_w_last) begin
        wr_addr[INC_MSB-1:0] <= wr_addr[INC_MSB-1:0] + 1;
    end
end

// write data

assign                  axi_w_ready     = wr_active && (!axi_b_valid || axi_b_ready);

assign                  wr_en           = {STRB{(axi_w_ready && axi_w_valid)}} & axi_w_strb;
assign                  wr_data         = axi_w_data;

// write response

assign                  axi_b_resp      = 2'b00;

always @(posedge clk) begin
    if(rst) begin
        axi_b_valid     <= 1'b0;
    end else begin
        if(axi_b_ready) begin
            axi_b_valid     <= 1'b0;
        end
        if(axi_w_ready && axi_w_valid && axi_w_last) begin
            axi_b_valid     <= 1'b1;
        end
    end
end


// ** Read **

// read command

reg                     rd_active;
reg     [LEN-1:0]       rd_len;
reg                     rd_last;

assign                  rd_en           = rd_active && (axi_r_ready || !axi_r_valid);

assign                  axi_ar_ready    = !rd_active || (rd_en && rd_last);

always @(posedge clk) begin
    if(rst) begin
        rd_active       <= 1'b0;
    end else begin
        if(rd_en && rd_last) begin
            rd_active       <= 1'b0;
        end
        if(axi_ar_ready && axi_ar_valid) begin
            rd_active       <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(axi_ar_ready && axi_ar_valid) begin
        rd_addr         <= axi_ar_addr[ LSB +: RAM_ADDR ];
        rd_len          <= axi_ar_len;
        rd_last         <= (axi_ar_len == 0);
    end
    if(rd_en && !rd_last) begin
        rd_addr[INC_MSB-1:0] <= rd_addr[INC_MSB-1:0] + 1;
        rd_len          <= rd_len - 1;
        rd_last         <= (rd_len == 1);
    end
end

// read data/response

always @(posedge clk) begin
    if(rst) begin
        axi_r_valid     <= 1'b0;
        axi_r_last      <= 1'b0;
    end else begin
        if(axi_r_ready) begin
            axi_r_valid     <= 1'b0;
            axi_r_last      <= 1'b0;
        end
        if(rd_en) begin
            axi_r_valid     <= 1'b1;
            axi_r_last      <= rd_last;
        end
    end
end

assign                  axi_r_data      = rd_data;
assign                  axi_r_resp      = 2'b00;


// simulation sanity checks

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @(posedge clk) begin
    if(rd_en && axi_r_valid && !axi_r_ready) begin
        `dlsc_error("lost read data");
    end
    if(axi_w_ready && axi_w_valid && axi_w_last && axi_b_valid && !axi_b_ready) begin
        `dlsc_error("lost write response");
    end
end

`include "dlsc_sim_bot.vh"
`endif


endmodule

