
module dlsc_pxdma_reader #(
    parameter APB_ADDR          = 32,               // size of APB address field
    parameter AXI_ADDR          = 32,               // size of AXI address field
    parameter AXI_LEN           = 4,                // size of AXI length field
    parameter AXI_MOT           = 16,               // maximum outstanding transactions
    parameter BUFFER            = 1024,             // size of read buffer, in bytes
    parameter MAX_H             = 1024,             // maximum horizontal resolution
    parameter MAX_V             = 1024,             // maximum vertical resolution
    parameter BYTES_PER_PIXEL   = 3,                // bytes per pixel; 1-4
    parameter PX_ASYNC          = 0,                // px_clk is asynchronous to clk
    // derived; don't touch
    parameter PX_DATA           = (BYTES_PER_PIXEL*8)
) (
    // System
    input   wire                    clk,
    input   wire                    rst,

    // APB register bus
    input   wire    [APB_ADDR-1:0]  apb_addr,
    input   wire                    apb_sel,
    input   wire                    apb_enable,
    input   wire                    apb_write,
    input   wire    [31:0]          apb_wdata,
    input   wire    [3:0]           apb_strb,
    output  wire                    apb_ready,
    output  wire    [31:0]          apb_rdata,

    // Interrupt
    output  wire                    int_out,

    // Status
    output  wire                    enabled,

    // Handshake
    input   wire                    row_written,    // done writing a row (in from pxdma_writer)
    output  wire                    row_read,       // done reading a row (out to pxdma_writer)
    
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

    // Pixel output
    input   wire                    px_clk,
    input   wire                    px_rst,
    input   wire                    px_ready,
    output  wire                    px_valid,
    output  wire    [PX_DATA-1:0]   px_data
);

`include "dlsc_synthesis.vh"

localparam  BLEN        = `dlsc_clog2(BYTES_PER_PIXEL*MAX_H);
localparam  XBITS       = `dlsc_clog2(MAX_H+1);
localparam  YBITS       = `dlsc_clog2(MAX_V+1);
localparam  FIFO_ADDR   = `dlsc_clog2(BUFFER/4);


// ** control **

wire                    rst_bus;
wire                    px_rst_bus;

wire                    axi_halt;
wire                    axi_busy;
wire                    axi_error;
wire                    axi_cmd_done;
wire                    axi_cmd_ready;
wire                    axi_cmd_valid;
wire    [AXI_ADDR-1:0]  axi_cmd_addr;
wire    [BLEN-1:0]      axi_cmd_bytes;
wire                    pack_cmd_ready;
wire                    pack_cmd_valid;
wire    [1:0]           pack_cmd_offset;
wire    [1:0]           pack_cmd_bpw;
wire    [XBITS-1:0]     pack_cmd_words;

dlsc_pxdma_control #(
    .APB_ADDR           ( APB_ADDR ),
    .AXI_ADDR           ( AXI_ADDR ),
    .BYTES_PER_PIXEL    ( BYTES_PER_PIXEL ),
    .BLEN               ( BLEN ),
    .XBITS              ( XBITS ),
    .YBITS              ( YBITS ),
    .ACKS               ( 1 ),
    .WRITER             ( 0 ),
    .PX_ASYNC           ( PX_ASYNC )
) dlsc_pxdma_control (
    .clk                ( clk ),
    .rst_in             ( rst ),
    .rst_bus            ( rst_bus ),
    .px_clk             ( px_clk ),
    .px_rst_in          ( px_rst ),
    .px_rst_bus         ( px_rst_bus ),
    .apb_addr           ( apb_addr ),
    .apb_sel            ( apb_sel ),
    .apb_enable         ( apb_enable ),
    .apb_write          ( apb_write ),
    .apb_wdata          ( apb_wdata ),
    .apb_strb           ( apb_strb ),
    .apb_ready          ( apb_ready ),
    .apb_rdata          ( apb_rdata ),
    .int_out            ( int_out ),
    .enabled            ( enabled ),
    .row_ack            ( row_written ),
    .row_done           ( row_read ),
    .axi_halt           ( axi_halt ),
    .axi_busy           ( axi_busy ),
    .axi_error          ( axi_error ),
    .axi_cmd_done       ( axi_cmd_done ),
    .axi_cmd_ready      ( axi_cmd_ready ),
    .axi_cmd_valid      ( axi_cmd_valid ),
    .axi_cmd_addr       ( axi_cmd_addr ),
    .axi_cmd_bytes      ( axi_cmd_bytes ),
    .pack_cmd_ready     ( pack_cmd_ready ),
    .pack_cmd_valid     ( pack_cmd_valid ),
    .pack_cmd_offset    ( pack_cmd_offset ),
    .pack_cmd_bpw       ( pack_cmd_bpw ),
    .pack_cmd_words     ( pack_cmd_words )
);

// ** reader **

wire    [FIFO_ADDR:0]   fifo_free;

wire                    fifo_ready;
wire                    fifo_valid;
wire    [31:0]          fifo_data;

dlsc_axi_reader #(
    .ADDR               ( AXI_ADDR ),
    .LEN                ( AXI_LEN ),
    .BLEN               ( BLEN ),
    .MOT                ( AXI_MOT ),
    .FIFO_ADDR          ( FIFO_ADDR ),
    .STROBE_EN          ( 0 ),
    .WARNINGS           ( 1 )
) dlsc_axi_reader (
    .clk                ( clk ),
    .rst                ( rst_bus ),
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
    .out_free           ( fifo_free ),
    .out_ready          ( fifo_ready ),
    .out_valid          ( fifo_valid ),
    .out_last           (  ),
    .out_data           ( fifo_data ),
    .out_strb           (  )
);

// ** FIFO **

wire                    fifo_empty;
wire                    fifo_full;

wire                    pack_ready;
wire                    pack_valid;
wire    [31:0]          pack_data;

assign                  fifo_ready      = !fifo_full;
assign                  pack_valid      = !fifo_empty;

generate
if(PX_ASYNC) begin:GEN_FIFO_ASYNC
    dlsc_fifo_async #(
        .ADDR               ( FIFO_ADDR ),
        .DATA               ( 32 )
    ) dlsc_fifo_async (
        .wr_clk             ( clk ),
        .wr_rst             ( rst_bus ),
        .wr_push            ( fifo_ready && fifo_valid ),
        .wr_data            ( fifo_data ),
        .wr_full            ( fifo_full ),
        .wr_almost_full     (  ),
        .wr_free            ( fifo_free ),
        .rd_clk             ( px_clk ),
        .rd_rst             ( px_rst_bus ),
        .rd_pop             ( pack_ready && pack_valid ),
        .rd_data            ( pack_data ),
        .rd_empty           ( fifo_empty ),
        .rd_almost_empty    (  ),
        .rd_count           (  )
    );
end else begin:GEN_FIFO_SYNC
    dlsc_fifo #(
        .ADDR               ( FIFO_ADDR ),
        .DATA               ( 32 ),
        .FREE               ( 1 )
    ) dlsc_fifo (
        .clk                ( clk ),
        .rst                ( rst_bus ),
        .wr_push            ( fifo_ready && fifo_valid ),
        .wr_data            ( fifo_data ),
        .wr_full            ( fifo_full ),
        .wr_almost_full     (  ),
        .wr_free            ( fifo_free ),
        .rd_pop             ( pack_ready && pack_valid ),
        .rd_data            ( pack_data ),
        .rd_empty           ( fifo_empty ),
        .rd_almost_empty    (  ),
        .rd_count           (  )
    );
end
endgenerate

// ** unpacker **

wire    [31:0]          px_data_padded;
assign                  px_data         = px_data_padded[PX_DATA-1:0];

wire                    px_pack_cmd_ready;
wire                    px_pack_cmd_valid;
wire    [1:0]           px_pack_cmd_offset;
wire    [1:0]           px_pack_cmd_bpw;
wire    [XBITS-1:0]     px_pack_cmd_words;

generate
if(PX_ASYNC) begin:GEN_PACK_ASYNC
    dlsc_domaincross_rvh #(
        .DATA       ( XBITS + 4 )
    ) dlsc_domaincross_rvh (
        .in_clk     ( clk ),
        .in_rst     ( rst_bus ),
        .in_ready   ( pack_cmd_ready ),
        .in_valid   ( pack_cmd_valid ),
        .in_data    ( { pack_cmd_offset, pack_cmd_bpw, pack_cmd_words } ),
        .out_clk    ( px_clk ),
        .out_rst    ( px_rst_bus ),
        .out_ready  ( px_pack_cmd_ready ),
        .out_valid  ( px_pack_cmd_valid ),
        .out_data   ( { px_pack_cmd_offset, px_pack_cmd_bpw, px_pack_cmd_words } )
    );

end else begin:GEN_PACK_SYNC
    assign  pack_cmd_ready      = px_pack_cmd_ready;
    assign  px_pack_cmd_valid   = pack_cmd_valid;
    assign  px_pack_cmd_offset  = pack_cmd_offset;
    assign  px_pack_cmd_bpw     = pack_cmd_bpw;
    assign  px_pack_cmd_words   = pack_cmd_words;
end
endgenerate

dlsc_data_unpacker #(
    .WLEN               ( XBITS ),
    .WORDS_ZERO         ( 0 )
) dlsc_data_unpacker (
    .clk                ( px_clk ),
    .rst                ( px_rst_bus ),
    .cmd_done           (  ),
    .cmd_ready          ( px_pack_cmd_ready ),
    .cmd_valid          ( px_pack_cmd_valid ),
    .cmd_offset         ( px_pack_cmd_offset ),
    .cmd_bpw            ( px_pack_cmd_bpw ),
    .cmd_words          ( px_pack_cmd_words ),
    .in_ready           ( pack_ready ),
    .in_valid           ( pack_valid ),
    .in_data            ( pack_data ),
    .out_ready          ( px_ready ),
    .out_valid          ( px_valid ),
    .out_last           (  ),
    .out_data           ( px_data_padded )
);

endmodule


