
module dlsc_pxdma_writer #(
    parameter APB_ADDR          = 32,               // size of APB address field
    parameter AXI_ADDR          = 32,               // size of AXI address field
    parameter AXI_LEN           = 4,                // size of AXI length field
    parameter AXI_MOT           = 16,               // maximum outstanding transactions
    parameter BUFFER            = ((2**AXI_LEN)*8), // size of write buffer, in bytes
    parameter MAX_H             = 1024,             // maximum horizontal resolution
    parameter MAX_V             = 1024,             // maximum vertical resolution
    parameter BYTES_PER_PIXEL   = 3,                // bytes per pixel; 1-4
    parameter READERS           = 1,                // number of downstream pxdma_readers
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
    output  wire    [READERS-1:0]   row_written,    // done writing a row (out to pxdma_reader(s))
    input   wire    [READERS-1:0]   row_read,       // done reading a row (in from pxdma_reader(s))

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

    // Pixel input
    input   wire                    px_clk,
    input   wire                    px_rst,
    output  wire                    px_ready,
    input   wire                    px_valid,
    input   wire    [PX_DATA-1:0]   px_data
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
    .ACKS               ( READERS ),
    .WRITER             ( 1 ),
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
    .row_ack            ( row_read ),
    .row_done           ( row_written ),
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

// ** packer **

wire    [31:0]          px_data_padded  = { {(32-PX_DATA){1'b0}}, px_data };

wire                    pack_ready;
wire                    pack_valid;
wire    [31:0]          pack_data;
wire    [3:0]           pack_strb;

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

dlsc_data_packer #(
    .WLEN               ( XBITS ),
    .WORDS_ZERO         ( 0 )
) dlsc_data_packer (
    .clk                ( px_clk ),
    .rst                ( px_rst_bus ),
    .cmd_done           (  ),
    .cmd_ready          ( px_pack_cmd_ready ),
    .cmd_valid          ( px_pack_cmd_valid ),
    .cmd_offset         ( px_pack_cmd_offset ),
    .cmd_bpw            ( px_pack_cmd_bpw ),
    .cmd_words          ( px_pack_cmd_words ),
    .in_ready           ( px_ready ),
    .in_valid           ( px_valid ),
    .in_data            ( px_data_padded ),
    .out_ready          ( pack_ready ),
    .out_valid          ( pack_valid ),
    .out_last           (  ),
    .out_data           ( pack_data ),
    .out_strb           ( pack_strb )
);

// ** FIFO **

wire                    fifo_empty;
wire                    fifo_full;
wire    [FIFO_ADDR:0]   fifo_count;

wire                    fifo_ready;
wire                    fifo_valid;
wire    [31:0]          fifo_data;
wire    [3:0]           fifo_strb;

assign                  pack_ready      = !fifo_full;
assign                  fifo_valid      = !fifo_empty;

generate
if(PX_ASYNC) begin:GEN_ASYNC
    dlsc_fifo_async #(
        .ADDR               ( FIFO_ADDR ),
        .DATA               ( 4+32 )
    ) dlsc_fifo_async (
        .wr_clk             ( px_clk ),
        .wr_rst             ( px_rst_bus ),
        .wr_push            ( pack_ready && pack_valid ),
        .wr_data            ( { pack_strb, pack_data } ),
        .wr_full            ( fifo_full ),
        .wr_almost_full     (  ),
        .wr_free            (  ),
        .rd_clk             ( clk ),
        .rd_rst             ( rst_bus ),
        .rd_pop             ( fifo_ready && fifo_valid ),
        .rd_data            ( { fifo_strb, fifo_data } ),
        .rd_empty           ( fifo_empty ),
        .rd_almost_empty    (  ),
        .rd_count           ( fifo_count )
    );
end else begin:GEN_SYNC
    dlsc_fifo #(
        .ADDR               ( FIFO_ADDR ),
        .DATA               ( 4+32 ),
        .COUNT              ( 1 )
    ) dlsc_fifo (
        .clk                ( clk ),
        .rst                ( rst_bus ),
        .wr_push            ( pack_ready && pack_valid ),
        .wr_data            ( { pack_strb, pack_data } ),
        .wr_full            ( fifo_full ),
        .wr_almost_full     (  ),
        .wr_free            (  ),
        .rd_pop             ( fifo_ready && fifo_valid ),
        .rd_data            ( { fifo_strb, fifo_data } ),
        .rd_empty           ( fifo_empty ),
        .rd_almost_empty    (  ),
        .rd_count           ( fifo_count )
    );
end
endgenerate

// ** writer **

dlsc_axi_writer #(
    .ADDR               ( AXI_ADDR ),
    .LEN                ( AXI_LEN ),
    .BLEN               ( BLEN ),
    .MOT                ( AXI_MOT ),
    .FIFO_ADDR          ( FIFO_ADDR ),
    .WARNINGS           ( 1 )
) dlsc_axi_writer (
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
    .in_count           ( fifo_count ),
    .in_ready           ( fifo_ready ),
    .in_valid           ( fifo_valid ),
    .in_data            ( fifo_data ),
    .in_strb            ( fifo_strb )
);

endmodule

