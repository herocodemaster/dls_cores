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
// DMA reader for image data.
// See dlsc_pxdma_control.v for details

module dlsc_pxdma_reader #(
    // ** Clock Domains **
    parameter CSR_DOMAIN        = 0,
    parameter AXI_DOMAIN        = 1,
    parameter PX_DOMAIN         = 2,
    // ** Config **
    parameter WRITERS           = 1,                    // number of writers this reader can handshake with
    parameter BUFFER            = 1024,                 // size of read buffer, in bytes
    parameter MAX_H             = 1024,                 // maximum horizontal resolution
    parameter MAX_V             = 1024,                 // maximum vertical resolution
    parameter BYTES_PER_PIXEL   = 3,                    // bytes per pixel; 1-4
    // derived; don't touch
    parameter PX_DATA           = (BYTES_PER_PIXEL*8),
    // ** AXI **
    parameter AXI_ADDR          = 32,                   // size of AXI address field
    parameter AXI_LEN           = 4,                    // size of AXI length field
    parameter AXI_MOT           = 16,                   // maximum outstanding transactions
    // ** CSR **
    parameter CSR_ADDR          = 32,
    parameter CORE_INSTANCE     = 32'h00000000          // 32-bit identifier to place in REG_CORE_INSTANCE field
) (
    // ** CSR Domain **

    // System
    input   wire                    csr_clk,
    input   wire                    csr_rst,
    output  wire                    csr_rst_out,        // asserted when engine is disabled

    // Status
    output  wire                    csr_enabled,        // asserted when engine is enabled

    // Handshake
    input   wire    [WRITERS-1:0]   csr_row_written,    // done writing a row (in from pxdma_writer(s))
    output  wire    [WRITERS-1:0]   csr_row_read,       // done reading a row (out to pxdma_writer(s))
    
    // CSR command
    input   wire                    csr_cmd_valid,
    input   wire                    csr_cmd_write,
    input   wire    [CSR_ADDR-1:0]  csr_cmd_addr,
    input   wire    [31:0]          csr_cmd_data,

    // CSR response
    output  wire                    csr_rsp_valid,
    output  wire                    csr_rsp_error,
    output  wire    [31:0]          csr_rsp_data,

    // Interrupt
    output  wire                    csr_int,

    // ** AXI Doamin **

    // System
    input   wire                    axi_clk,
    input   wire                    axi_rst,
    output  wire                    axi_rst_out,        // asserted when engine is disabled
    
    // AXI read command
    input   wire                    axi_ar_ready,
    output  wire                    axi_ar_valid,
    output  wire    [AXI_ADDR-1:0]  axi_ar_addr,
    output  wire    [AXI_LEN-1:0]   axi_ar_len,

    // AXI read response
    output  wire                    axi_r_ready,
    input   wire                    axi_r_valid,
    input   wire                    axi_r_last,
    input   wire    [31:0]          axi_r_data,
    input   wire    [1:0]           axi_r_resp,

    // ** Pixel Domain **
    
    // System
    input   wire                    px_clk,
    input   wire                    px_rst,
    output  wire                    px_rst_out,         // asserted when engine is disabled

    // Pixel output
    input   wire                    px_ready,
    output  wire                    px_valid,
    output  wire    [PX_DATA-1:0]   px_data
);

localparam  CORE_MAGIC  = 32'ha45d9915; // lower 32 bits of md5sum of "dlsc_pxdma_reader"

`include "dlsc_clog2.vh"

localparam  BLEN        = `dlsc_clog2(BYTES_PER_PIXEL*MAX_H);
localparam  XBITS       = `dlsc_clog2(MAX_H+1);
localparam  YBITS       = `dlsc_clog2(MAX_V+1);
localparam  FIFO_ADDR   = `dlsc_clog2(BUFFER/4);

// ** Control **

wire                    axi_halt;
wire                    axi_busy;
wire                    axi_error;
wire                    axi_cmd_done;
wire                    axi_cmd_ready;
wire                    axi_cmd_valid;
wire    [AXI_ADDR-1:0]  axi_cmd_addr;
wire    [BLEN-1:0]      axi_cmd_bytes;

wire                    px_cmd_ready;
wire                    px_cmd_valid;
wire    [1:0]           px_cmd_offset;
wire    [1:0]           px_cmd_bpw;
wire    [XBITS-1:0]     px_cmd_words;

dlsc_pxdma_control #(
    .CSR_DOMAIN         ( CSR_DOMAIN ),
    .AXI_DOMAIN         ( AXI_DOMAIN ),
    .PX_DOMAIN          ( PX_DOMAIN ),
    .WRITER             ( 0 ),
    .ACKS               ( WRITERS ),
    .AF_ADDR            ( 4 ),                  // 16 buffer address entries in FIFO
    .BYTES_PER_PIXEL    ( BYTES_PER_PIXEL ),
    .XBITS              ( XBITS ),
    .YBITS              ( YBITS ),
    .BLEN               ( BLEN ),
    .AXI_ADDR           ( AXI_ADDR ),
    .AXI_MOT            ( AXI_MOT ),
    .CSR_ADDR           ( CSR_ADDR ),
    .CORE_MAGIC         ( CORE_MAGIC ),
    .CORE_INSTANCE      ( CORE_INSTANCE )
) dlsc_pxdma_control (
    // ** CSR Domain **
    .csr_clk            ( csr_clk ),
    .csr_rst            ( csr_rst ),
    .csr_rst_out        ( csr_rst_out ),
    .csr_enabled        ( csr_enabled ),
    .csr_row_ack        ( csr_row_written ),
    .csr_row_done       ( csr_row_read ),
    .csr_cmd_valid      ( csr_cmd_valid ),
    .csr_cmd_write      ( csr_cmd_write ),
    .csr_cmd_addr       ( csr_cmd_addr ),
    .csr_cmd_data       ( csr_cmd_data ),
    .csr_rsp_valid      ( csr_rsp_valid ),
    .csr_rsp_error      ( csr_rsp_error ),
    .csr_rsp_data       ( csr_rsp_data ),
    .csr_int            ( csr_int ),
    // ** AXI Doamin **
    .axi_clk            ( axi_clk ),
    .axi_rst            ( axi_rst ),
    .axi_rst_out        ( axi_rst_out ),
    .axi_halt           ( axi_halt ),
    .axi_busy           ( axi_busy ),
    .axi_error          ( axi_error ),
    .axi_cmd_done       ( axi_cmd_done ),
    .axi_cmd_ready      ( axi_cmd_ready ),
    .axi_cmd_valid      ( axi_cmd_valid ),
    .axi_cmd_addr       ( axi_cmd_addr ),
    .axi_cmd_bytes      ( axi_cmd_bytes ),
    // ** Pixel Domain **
    .px_clk             ( px_clk ),
    .px_rst             ( px_rst ),
    .px_rst_out         ( px_rst_out ),
    .px_cmd_ready       ( px_cmd_ready ),
    .px_cmd_valid       ( px_cmd_valid ),
    .px_cmd_offset      ( px_cmd_offset ),
    .px_cmd_bpw         ( px_cmd_bpw ),
    .px_cmd_words       ( px_cmd_words )
);

// ** Reader **

wire    [FIFO_ADDR:0]   axi_fifo_free;

wire                    axi_fifo_ready;
wire                    axi_fifo_valid;
wire    [31:0]          axi_fifo_data;

dlsc_axi_reader #(
    .ADDR               ( AXI_ADDR ),
    .LEN                ( AXI_LEN ),
    .BLEN               ( BLEN ),
    .MOT                ( AXI_MOT ),
    .FIFO_ADDR          ( FIFO_ADDR ),
    .STROBE_EN          ( 0 ),
    .WARNINGS           ( 1 )
) dlsc_axi_reader (
    .clk                ( axi_clk ),
    .rst                ( axi_rst_out ),
    .axi_halt           ( axi_halt ),
    .axi_busy           ( axi_busy ),
    .axi_error          ( axi_error ),
    .cmd_done           ( axi_cmd_done ),
    .cmd_ready          ( axi_cmd_ready ),
    .cmd_valid          ( axi_cmd_valid ),
    .cmd_addr           ( axi_cmd_addr ),
    .cmd_bytes          ( axi_cmd_bytes ),
    .axi_ar_ready       ( axi_ar_ready ),
    .axi_ar_valid       ( axi_ar_valid ),
    .axi_ar_addr        ( axi_ar_addr ),
    .axi_ar_len         ( axi_ar_len ),
    .axi_r_ready        ( axi_r_ready ),
    .axi_r_valid        ( axi_r_valid ),
    .axi_r_last         ( axi_r_last ),
    .axi_r_data         ( axi_r_data ),
    .axi_r_resp         ( axi_r_resp ),
    .out_free           ( axi_fifo_free ),
    .out_ready          ( axi_fifo_ready ),
    .out_valid          ( axi_fifo_valid ),
    .out_last           (  ),
    .out_data           ( axi_fifo_data ),
    .out_strb           (  )
);

// ** Buffer FIFO **
// Buffer FIFO lives completely in AXI domain to prevent AXI deadlock if pixel
// domain enters reset while there are outstanding AXI transactions.

wire                    axi_fifo_full;
assign                  axi_fifo_ready      = !axi_fifo_full;

wire                    axi_pack_pop;
wire                    axi_pack_empty;
wire    [31:0]          axi_pack_data;

dlsc_fifo #(
    .ADDR           ( FIFO_ADDR ),
    .DATA           ( 32 ),
    .FREE           ( 1 )
) dlsc_fifo_buffer (
    .clk            ( axi_clk ),
    .rst            ( axi_rst_out ),
    .wr_push        ( axi_fifo_ready && axi_fifo_valid ),
    .wr_data        ( axi_fifo_data ),
    .wr_full        ( axi_fifo_full ),
    .wr_almost_full (  ),
    .wr_free        ( axi_fifo_free ),
    .rd_pop         ( axi_pack_pop ),
    .rd_data        ( axi_pack_data ),
    .rd_empty       ( axi_pack_empty ),
    .rd_almost_empty (  ),
    .rd_count       (  )
);

// ** Async FIFO **
// A small, separate async FIFO is used to bridge between the two clock domains,
// if necessary.

wire                    px_pack_pop;
wire                    px_pack_empty;
wire    [31:0]          px_pack_data;

generate
if(AXI_DOMAIN != PX_DOMAIN) begin:GEN_FIFO_ASYNC

    wire                    axi_pack_full;
    assign                  axi_pack_pop        = !axi_pack_empty && !axi_pack_full;

    dlsc_fifo_async #(
        .ADDR           ( 4 ),      // shallow
        .DATA           ( 32 )
    ) dlsc_fifo_async (
        .wr_clk         ( axi_clk ),
        .wr_rst         ( axi_rst_out ),
        .wr_push        ( axi_pack_pop ),
        .wr_data        ( axi_pack_data ),
        .wr_full        ( axi_pack_full ),
        .wr_almost_full (  ),
        .wr_free        (  ),
        .rd_clk         ( px_clk ),
        .rd_rst         ( px_rst_out ),
        .rd_pop         ( px_pack_pop ),
        .rd_data        ( px_pack_data ),
        .rd_empty       ( px_pack_empty ),
        .rd_almost_empty (  ),
        .rd_count       (  )
    );

end else begin:GEN_FIFO_SYNC

    // just connect sync FIFO directly to unpacker
    assign axi_pack_pop     = px_pack_pop;
    assign px_pack_empty    = axi_pack_empty;
    assign px_pack_data     = axi_pack_data;

end
endgenerate

// ** Unpacker **

wire                    px_pack_ready;
wire                    px_pack_valid   = !px_pack_empty;
assign                  px_pack_pop     = px_pack_ready && px_pack_valid;

wire    [31:0]          px_data_padded;
assign                  px_data         = px_data_padded[PX_DATA-1:0];

dlsc_data_unpacker #(
    .WLEN               ( XBITS ),
    .WORDS_ZERO         ( 0 )
) dlsc_data_unpacker (
    .clk                ( px_clk ),
    .rst                ( px_rst_out ),
    .cmd_done           (  ),
    .cmd_ready          ( px_cmd_ready ),
    .cmd_valid          ( px_cmd_valid ),
    .cmd_offset         ( px_cmd_offset ),
    .cmd_bpw            ( px_cmd_bpw ),
    .cmd_words          ( px_cmd_words ),
    .in_ready           ( px_pack_ready ),
    .in_valid           ( px_pack_valid ),
    .in_data            ( px_pack_data ),
    .out_ready          ( px_ready ),
    .out_valid          ( px_valid ),
    .out_last           (  ),
    .out_data           ( px_data_padded )
);

endmodule

