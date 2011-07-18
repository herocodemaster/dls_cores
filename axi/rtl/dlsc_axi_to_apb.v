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
// Interfaces an AXI master to an APB slave.

module dlsc_axi_to_apb #(
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
    output  reg     [DATA-1:0]      axi_r_data,
    output  reg     [1:0]           axi_r_resp,

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
    output  reg     [1:0]           axi_b_resp,

    // ** APB **

    output  reg     [ADDR-1:0]      apb_addr,
    output  reg                     apb_sel,
    output  reg                     apb_enable,
    output  reg                     apb_write,
    output  reg     [DATA-1:0]      apb_wdata,
    output  reg     [STRB-1:0]      apb_strb,
    input   wire                    apb_ready,
    input   wire    [DATA-1:0]      apb_rdata,
    input   wire                    apb_slverr
);

`include "dlsc_clog2.vh"

localparam  LSB             = `dlsc_clog2(STRB);

localparam  AXI_RESP_OKAY   = 2'b00,
            AXI_RESP_SLVERR = 2'b10;


// Buffer write data

wire            w_full;
assign          axi_w_ready     = !w_full;
wire            w_push          = (axi_w_ready && axi_w_valid);

wire            w_empty;
wire            w_pop;

wire [DATA-1:0] w_data;
wire [STRB-1:0] w_strb;

dlsc_fifo #(
    .DATA           ( DATA+STRB ),
    .DEPTH          ( 16 ),
    .FAST_FLAGS     ( 1 )
) dlsc_fifo_w (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( w_push ),
    .wr_data        ( { axi_w_strb, axi_w_data } ),
    .wr_full        ( w_full ),
    .wr_almost_full (  ),
    .wr_free        (  ),
    .rd_pop         ( w_pop ),
    .rd_data        ( { w_strb, w_data } ),
    .rd_empty       ( w_empty ),
    .rd_almost_empty(  ),
    .rd_count       (  )
);


// Arbitrate

wire            cmd_ready;
reg             cmd_valid;
reg  [LEN-1:0]  cmd_len;
reg             cmd_last;

assign          axi_ar_ready    = !cmd_valid && ( apb_write || !axi_aw_valid);
assign          axi_aw_ready    = !cmd_valid && (!apb_write || !axi_ar_valid);

wire            apb_xfer        = (apb_sel && apb_enable && apb_ready);

assign          cmd_ready       = apb_xfer && cmd_last;


always @(posedge clk) begin
    if(rst) begin
        cmd_valid   <= 1'b0;
        apb_write   <= 1'b0;
    end else begin
        if(cmd_ready) begin
            cmd_valid   <= 1'b0;
        end
        if(axi_ar_ready && axi_ar_valid) begin
            cmd_valid   <= 1'b1;
            apb_write   <= 1'b0;
        end
        if(axi_aw_ready && axi_aw_valid) begin
            cmd_valid   <= 1'b1;
            apb_write   <= 1'b1;
        end
    end
end


// Address

always @(posedge clk) begin
    if(axi_ar_ready && axi_ar_valid) begin
        apb_addr    <= { axi_ar_addr[ADDR-1:LSB], {LSB{1'b0}} };
        cmd_len     <= axi_ar_len;
        cmd_last    <= (axi_ar_len == 0);
    end
    if(axi_aw_ready && axi_aw_valid) begin
        apb_addr    <= { axi_aw_addr[ADDR-1:LSB], {LSB{1'b0}} };
        cmd_len     <= axi_aw_len;
        cmd_last    <= (axi_aw_len == 0);
    end
    if(apb_xfer && !cmd_last) begin
        apb_addr[11:LSB] <= apb_addr[11:LSB] + 1;
        cmd_len     <= cmd_len - 1;
        cmd_last    <= (cmd_len == 1);
    end
end


// Handshaking

reg             apb_last;

assign          w_pop           = (!axi_b_valid               ) && !w_empty && ((axi_aw_ready && axi_aw_valid) || (cmd_valid && !apb_last &&  apb_write && (!apb_sel || apb_xfer)));

wire            r_setup         = (!axi_r_valid || axi_r_ready) &&             ((axi_ar_ready && axi_ar_valid) || (cmd_valid && !apb_last && !apb_write && (!apb_sel            )));

always @(posedge clk) begin
    if(rst) begin
        apb_sel     <= 1'b0;
        apb_enable  <= 1'b0;
        apb_last    <= 1'b0;
    end else begin
        if(apb_xfer) begin
            apb_sel     <= 1'b0;
            apb_enable  <= 1'b0;
            apb_last    <= 1'b0;
        end
        if(apb_sel && !apb_enable) begin
            apb_enable  <= 1'b1;
            apb_last    <= cmd_last;
        end
        if(w_pop || r_setup) begin
            apb_sel     <= 1'b1;
        end
    end
end


// Read data

always @(posedge clk) begin
    if(rst) begin
        axi_r_valid <= 1'b0;
    end else begin
        if(axi_r_ready && axi_r_valid) begin
            axi_r_valid <= 1'b0;
        end
        if(apb_xfer && !apb_write) begin
            axi_r_valid <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(apb_xfer && !apb_write) begin
        axi_r_data  <= apb_rdata;
        axi_r_resp  <= apb_slverr ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
        axi_r_last  <= apb_last;
    end
end


// Write data

always @(posedge clk) begin
    if(w_pop) begin
        apb_wdata   <= w_data;
        apb_strb    <= w_strb;
    end
    if(r_setup) begin
        apb_strb    <= 0;
    end
end


// Write response

always @(posedge clk) begin
    if(rst) begin
        axi_b_valid <= 1'b0;
        axi_b_resp  <= AXI_RESP_OKAY;
    end else begin
        if(axi_b_ready && axi_b_valid) begin
            axi_b_valid <= 1'b0;
            axi_b_resp  <= AXI_RESP_OKAY;
        end
        if(apb_xfer && apb_write) begin
            axi_b_valid <= apb_last;
            axi_b_resp  <= apb_slverr ? AXI_RESP_SLVERR : axi_b_resp;
        end
    end
end


endmodule

