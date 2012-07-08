
module dlsc_pxdma_writer #(
    // ** Clock Domains **
    parameter CSR_DOMAIN        = 0,
    parameter AXI_DOMAIN        = 1,
    parameter PX_DOMAIN         = 2,
    // ** Config **
    parameter READERS           = 1,                    // number of readers this writer can handshake with
    parameter BUFFER            = 1024,                 // size of write buffer, in bytes
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
    output  wire    [READERS-1:0]   csr_row_written,    // done writing a row (out to pxdma_reader(s))
    input   wire    [READERS-1:0]   csr_row_read,       // done reading a row (in from pxdma_reader(s))
    
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

    // AXI write command
    input   wire                    axi_aw_ready,
    output  wire                    axi_aw_valid,
    output  wire    [AXI_ADDR-1:0]  axi_aw_addr,
    output  wire    [AXI_LEN-1:0]   axi_aw_len,

    // AXI write data
    input   wire                    axi_w_ready,
    output  wire                    axi_w_valid,
    output  wire                    axi_w_last,
    output  wire    [31:0]          axi_w_data,
    output  wire    [3:0]           axi_w_strb,

    // AXI write response
    output  wire                    axi_b_ready,
    input   wire                    axi_b_valid,
    input   wire    [1:0]           axi_b_resp,

    // ** Pixel Domain **
    
    // System
    input   wire                    px_clk,
    input   wire                    px_rst,
    output  wire                    px_rst_out,         // asserted when engine is disabled

    // Pixel input
    output  wire                    px_ready,
    input   wire                    px_valid,
    input   wire    [PX_DATA-1:0]   px_data
);

localparam  CORE_MAGIC  = 32'h4a0e0c46; // lower 32 bits of md5sum of "dlsc_pxdma_writer"

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
    .WRITER             ( 1 ),
    .ACKS               ( READERS ),
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
    .csr_row_ack        ( csr_row_read ),
    .csr_row_done       ( csr_row_written ),
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

// ** Packer **

wire    [31:0]          px_data_padded  = { {(32-PX_DATA){1'b0}}, px_data };

wire                    px_pack_ready;
wire                    px_pack_valid;
wire                    px_pack_last;
wire    [31:0]          px_pack_data;
wire    [3:0]           px_pack_strb;

dlsc_data_packer #(
    .WLEN               ( XBITS ),
    .WORDS_ZERO         ( 0 )
) dlsc_data_packer (
    .clk                ( px_clk ),
    .rst                ( px_rst_out ),
    .cmd_done           (  ),
    .cmd_ready          ( px_cmd_ready ),
    .cmd_valid          ( px_cmd_valid ),
    .cmd_offset         ( px_cmd_offset ),
    .cmd_bpw            ( px_cmd_bpw ),
    .cmd_words          ( px_cmd_words ),
    .in_ready           ( px_ready ),
    .in_valid           ( px_valid ),
    .in_data            ( px_data_padded ),
    .out_ready          ( px_pack_ready ),
    .out_valid          ( px_pack_valid ),
    .out_last           ( px_pack_last ),
    .out_data           ( px_pack_data ),
    .out_strb           ( px_pack_strb )
);

// ** Async FIFO **
// A small, separate async FIFO is used to bridge between the two clock domains,
// if necessary.

wire                    axi_pack_full;
wire                    axi_pack_push;
wire    [31:0]          axi_pack_data;
wire    [3:0]           axi_pack_strb;

generate
if(AXI_DOMAIN != PX_DOMAIN) begin:GEN_FIFO_ASYNC

    wire                    px_pack_full;
    assign                  px_pack_ready       = !px_pack_full;
    wire                    axi_pack_empty;
    assign                  axi_pack_push       = !axi_pack_empty && !axi_pack_full;

    dlsc_fifo_async #(
        .ADDR           ( 4 ),      // shallow
        .DATA           ( 4+32 )
    ) dlsc_fifo_async (
        .wr_clk         ( px_clk ),
        .wr_rst         ( px_rst_out ),
        .wr_push        ( px_pack_ready && px_pack_valid ),
        .wr_data        ( {px_pack_strb,px_pack_data} ),
        .wr_full        ( px_pack_full ),
        .wr_almost_full (  ),
        .wr_free        (  ),
        .rd_clk         ( axi_clk ),
        .rd_rst         ( axi_rst_out ),
        .rd_pop         ( axi_pack_push ),
        .rd_data        ( {axi_pack_strb,axi_pack_data} ),
        .rd_empty       ( axi_pack_empty ),
        .rd_almost_empty (  ),
        .rd_count       (  )
    );

end else begin:GEN_FIFO_SYNC

    // just connect packer directly to sync FIFO
    assign px_pack_ready    = !axi_pack_full;
    assign axi_pack_push    = px_pack_ready && px_pack_valid;
    assign axi_pack_data    = px_pack_data;
    assign axi_pack_strb    = px_pack_strb;

end
endgenerate

// ** Buffer FIFO **
// Buffer FIFO lives completely in AXI domain to prevent AXI deadlock if pixel
// domain enters reset while there are outstanding AXI transactions.

wire                    axi_fifo_empty;
wire    [FIFO_ADDR:0]   axi_fifo_count;

wire                    axi_fifo_ready;
wire                    axi_fifo_valid      = !axi_fifo_empty;

wire    [31:0]          axi_fifo_data;
wire    [3:0]           axi_fifo_strb;

dlsc_fifo #(
    .ADDR           ( FIFO_ADDR ),
    .DATA           ( 4+32 ),
    .COUNT          ( 1 )
) dlsc_fifo_buffer (
    .clk            ( axi_clk ),
    .rst            ( axi_rst_out ),
    .wr_push        ( axi_pack_push ),
    .wr_data        ( {axi_pack_strb,axi_pack_data} ),
    .wr_full        ( axi_pack_full ),
    .wr_almost_full (  ),
    .wr_free        (  ),
    .rd_pop         ( axi_fifo_ready && axi_fifo_valid ),
    .rd_data        ( {axi_fifo_strb,axi_fifo_data} ),
    .rd_empty       ( axi_fifo_empty ),
    .rd_almost_empty (  ),
    .rd_count       ( axi_fifo_count )
);

// ** Writer **

dlsc_axi_writer #(
    .ADDR               ( AXI_ADDR ),
    .LEN                ( AXI_LEN ),
    .BLEN               ( BLEN ),
    .MOT                ( AXI_MOT ),
    .FIFO_ADDR          ( FIFO_ADDR ),
    .WARNINGS           ( 1 )
) dlsc_axi_writer (
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
    .axi_aw_ready       ( axi_aw_ready ),
    .axi_aw_valid       ( axi_aw_valid ),
    .axi_aw_addr        ( axi_aw_addr ),
    .axi_aw_len         ( axi_aw_len ),
    .axi_w_ready        ( axi_w_ready ),
    .axi_w_valid        ( axi_w_valid ),
    .axi_w_last         ( axi_w_last ),
    .axi_w_data         ( axi_w_data ),
    .axi_w_strb         ( axi_w_strb ),
    .axi_b_ready        ( axi_b_ready ),
    .axi_b_valid        ( axi_b_valid ),
    .axi_b_resp         ( axi_b_resp ),
    .in_count           ( axi_fifo_count ),
    .in_ready           ( axi_fifo_ready ),
    .in_valid           ( axi_fifo_valid ),
    .in_data            ( axi_fifo_data ),
    .in_strb            ( axi_fifo_strb )
);


`ifdef SIMULATION

integer cnt_px_valid;
integer cnt_px_cmd_valid;
integer cnt_px_pack_valid;
integer cnt_px_pack_last;

always @(posedge px_clk) begin
    if(px_rst_out) begin
        cnt_px_valid <= 0;
        cnt_px_cmd_valid <= 0;
        cnt_px_pack_valid <= 0;
        cnt_px_pack_last <= 0;
    end else begin
        if(px_ready && px_valid) begin
            cnt_px_valid <= cnt_px_valid + 1;
        end
        if(px_cmd_ready && px_cmd_valid) begin
            cnt_px_cmd_valid <= cnt_px_cmd_valid + 1;
        end
        if(px_pack_ready && px_pack_valid) begin
            cnt_px_pack_valid <= cnt_px_pack_valid + 1;
            if(px_pack_last) begin
                cnt_px_pack_last <= cnt_px_pack_last + 1;
            end
        end
    end
end

integer cnt_axi_cmd_valid;
integer cnt_axi_cmd_done;
integer cnt_axi_pack_push;
integer cnt_axi_fifo_valid;

always @(posedge axi_clk) begin
    if(axi_rst_out) begin
        cnt_axi_cmd_valid <= 0;
        cnt_axi_cmd_done <= 0;
        cnt_axi_pack_push <= 0;
        cnt_axi_fifo_valid <= 0;
    end else begin
        if(axi_cmd_ready && axi_cmd_valid) begin
            cnt_axi_cmd_valid <= cnt_axi_cmd_valid + 1;
        end
        if(axi_cmd_done) begin
            cnt_axi_cmd_done <= cnt_axi_cmd_done + 1;
        end
        if(axi_pack_push) begin
            cnt_axi_pack_push <= cnt_axi_pack_push + 1;
        end
        if(axi_fifo_ready && axi_fifo_valid) begin
            cnt_axi_fifo_valid <= cnt_axi_fifo_valid + 1;
        end
    end
end

`endif

endmodule

