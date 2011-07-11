
module dlsc_pcie_s6_inbound #(
    parameter ADDR          = 32,
    parameter LEN           = 4,
    parameter WRITE_BUFFER  = 32,
    parameter WRITE_MOT     = 16,
    parameter READ_BUFFER   = 256,
    parameter READ_MOT      = 16
) (
    // ** System **

    input   wire                clk,
    input   wire                rst,
    
    // ** AXI **
    
    // AXI read command
    input   wire                axi_ar_ready,
    output  wire                axi_ar_valid,
    output  wire    [ADDR-1:0]  axi_ar_addr,
    output  wire    [LEN-1:0]   axi_ar_len,

    // AXI read response
    output  wire                axi_r_ready,
    input   wire                axi_r_valid,
    input   wire                axi_r_last,
    input   wire    [31:0]      axi_r_data,
    input   wire    [1:0]       axi_r_resp,

    // AXI write command
    input   wire                axi_aw_ready,
    output  wire                axi_aw_valid,
    output  wire    [ADDR-1:0]  axi_aw_addr,
    output  wire    [LEN-1:0]   axi_aw_len,

    // AXI write data
    input   wire                axi_w_ready,
    output  wire                axi_w_valid,
    output  wire                axi_w_last,
    output  wire    [31:0]      axi_w_data,
    output  wire    [3:0]       axi_w_strb,

    // AXI write response
    output  wire                axi_b_ready,
    input   wire                axi_b_valid,
    input   wire    [1:0]       axi_b_resp,
    
    // ** PCIe **

    // Status
    output  wire                rx_np_ok,
    
    // Config
    input   wire    [2:0]       max_payload_size,
    
    // PCIe ID
    input   wire    [7:0]       bus_number,
    input   wire    [4:0]       dev_number,
    input   wire    [2:0]       func_number,

    // TLP receive input (requests only)
    output  wire                rx_ready,
    input   wire                rx_valid,
    input   wire    [31:0]      rx_data,
    input   wire                rx_last,
    input   wire                rx_err,
    input   wire    [6:0]       rx_bar,

    // TLP output
    input   wire                tx_ready,
    output  wire                tx_valid,
    output  wire    [31:0]      tx_data,
    output  wire                tx_last,

    // Error reporting
    input   wire                err_ready,
    output  wire                err_valid,
    output  wire                err_unsupported
);

`include "dlsc_clog2.vh"

localparam  WRITE_BUFA          = `dlsc_clog2(WRITE_BUFFER);
localparam  READ_BUFA           = `dlsc_clog2(READ_BUFFER);

localparam  TOKN                = 6;


// ** Address Translator (TODO) **
    
wire            trans_req;
wire [2:0]      trans_req_bar;
wire [63:2]     trans_req_addr;
wire            trans_req_64;
reg             trans_ack;
reg  [ADDR-1:2] trans_ack_addr;

always @(posedge clk) begin
    trans_ack       <= trans_req;
    trans_ack_addr  <= { trans_req_bar, trans_req_addr[ADDR-4:2] };
end


// ** TLP decode **
    
wire            tlp_h_ready;
wire            tlp_h_valid;
wire            tlp_h_np;
wire            tlp_h_write;
wire            tlp_h_mem;
wire [ADDR-1:2] tlp_h_addr;
wire [9:0]      tlp_h_len;
wire [3:0]      tlp_h_be_first;
wire [3:0]      tlp_h_be_last;
wire            tlp_id_ready;
wire            tlp_id_valid;
wire            tlp_id_write;
wire [28:0]     tlp_id_data;
wire            tlp_d_ready;
wire            tlp_d_valid;
wire            tlp_d_last;
wire [31:0]     tlp_d_data;
wire [3:0]      tlp_d_strb;

dlsc_pcie_s6_inbound_decode #(
    .ADDR           ( ADDR )
) dlsc_pcie_s6_inbound_decode_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .trans_req      ( trans_req ),
    .trans_req_bar  ( trans_req_bar ),
    .trans_req_addr ( trans_req_addr ),
    .trans_req_64   ( trans_req_64 ),
    .trans_ack      ( trans_ack ),
    .trans_ack_addr ( trans_ack_addr ),
    .rx_ready       ( rx_ready ),
    .rx_valid       ( rx_valid ),
    .rx_data        ( rx_data ),
    .rx_last        ( rx_last ),
    .rx_err         ( rx_err ),
    .rx_bar         ( rx_bar ),
    .tlp_h_ready    ( tlp_h_ready ),
    .tlp_h_valid    ( tlp_h_valid ),
    .tlp_h_np       ( tlp_h_np ),
    .tlp_h_write    ( tlp_h_write ),
    .tlp_h_mem      ( tlp_h_mem ),
    .tlp_h_addr     ( tlp_h_addr ),
    .tlp_h_len      ( tlp_h_len ),
    .tlp_h_be_first ( tlp_h_be_first ),
    .tlp_h_be_last  ( tlp_h_be_last ),
    .tlp_id_ready   ( tlp_id_ready ),
    .tlp_id_valid   ( tlp_id_valid ),
    .tlp_id_write   ( tlp_id_write ),
    .tlp_id_data    ( tlp_id_data ),
    .tlp_d_ready    ( tlp_d_ready ),
    .tlp_d_valid    ( tlp_d_valid ),
    .tlp_d_last     ( tlp_d_last ),
    .tlp_d_data     ( tlp_d_data ),
    .tlp_d_strb     ( tlp_d_strb )
);


// ** Dispatch **
    
wire            rd_tlp_h_ready;
wire            rd_tlp_h_valid;
wire [TOKN-1:0] rd_tlp_h_token;
wire            wr_tlp_h_ready;
wire            wr_tlp_h_valid;
wire [TOKN-1:0] wr_tlp_h_token;
wire [TOKN-1:0] token_oldest;

dlsc_pcie_s6_inbound_dispatch #(
    .TOKN           ( TOKN )
) dlsc_pcie_s6_inbound_dispatch_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .tlp_h_ready    ( tlp_h_ready ),
    .tlp_h_valid    ( tlp_h_valid ),
    .tlp_h_write    ( tlp_h_write ),
    .rd_h_ready     ( rd_tlp_h_ready ),
    .rd_h_valid     ( rd_tlp_h_valid ),
    .rd_h_token     ( rd_tlp_h_token ),
    .wr_h_ready     ( wr_tlp_h_ready ),
    .wr_h_valid     ( wr_tlp_h_valid ),
    .wr_h_token     ( wr_tlp_h_token ),
    .token_oldest   ( token_oldest )
);


// ** Write **

wire [TOKN-1:0] token_wr;
wire            wr_cpl_h_ready;
wire            wr_cpl_h_valid;
wire [1:0]      wr_cpl_h_resp;

dlsc_pcie_s6_inbound_write #(
    .ADDR           ( ADDR ),
    .LEN            ( LEN ),
    .BUFA           ( WRITE_BUFA ),
    .MOT            ( WRITE_MOT ),
    .TOKN           ( TOKN )
) dlsc_pcie_s6_inbound_write_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .token_wr       ( token_wr ),
    .req_h_ready    ( wr_tlp_h_ready ),
    .req_h_valid    ( wr_tlp_h_valid ),
    .req_h_np       ( tlp_h_np ),
    .req_h_addr     ( tlp_h_addr ),
    .req_h_len      ( tlp_h_len ),
    .req_h_token    ( wr_tlp_h_token ),
    .req_d_ready    ( tlp_d_ready ),
    .req_d_valid    ( tlp_d_valid ),
    .req_d_data     ( tlp_d_data ),
    .req_d_strb     ( tlp_d_strb ),
    .cpl_h_ready    ( wr_cpl_h_ready ),
    .cpl_h_valid    ( wr_cpl_h_valid ),
    .cpl_h_resp     ( wr_cpl_h_resp ),
    .err_ready      ( err_ready ),
    .err_valid      ( err_valid ),
    .err_unsupported ( err_unsupported ),
    .axi_aw_ready   ( axi_aw_ready ),
    .axi_aw_valid   ( axi_aw_valid ),
    .axi_aw_addr    ( axi_aw_addr ),
    .axi_aw_len     ( axi_aw_len ),
    .axi_w_ready    ( axi_w_ready ),
    .axi_w_valid    ( axi_w_valid ),
    .axi_w_last     ( axi_w_last ),
    .axi_w_data     ( axi_w_data ),
    .axi_w_strb     ( axi_w_strb ),
    .axi_b_ready    ( axi_b_ready ),
    .axi_b_valid    ( axi_b_valid ),
    .axi_b_resp     ( axi_b_resp )
);


// ** Read **
    
wire            rd_cpl_h_ready;
wire            rd_cpl_h_valid;
wire [6:0]      rd_cpl_h_addr;
wire [9:0]      rd_cpl_h_len;
wire [11:0]     rd_cpl_h_bytes;
wire            rd_cpl_h_last;
wire [1:0]      rd_cpl_h_resp;
wire            rd_cpl_d_ready;
wire            rd_cpl_d_valid;
wire [31:0]     rd_cpl_d_data;
wire            rd_cpl_d_last;

dlsc_pcie_s6_inbound_read #(
    .ADDR           ( ADDR ),
    .LEN            ( LEN ),
    .BUFA           ( READ_BUFA ),
    .MOT            ( READ_MOT ),
    .TOKN           ( TOKN )
) dlsc_pcie_s6_inbound_read_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .rx_np_ok       (  ),
    .max_payload_size ( max_payload_size ),
    .token_oldest   ( token_oldest ),
    .token_wr       ( token_wr ),
    .req_h_ready    ( rd_tlp_h_ready ),
    .req_h_valid    ( rd_tlp_h_valid ),
    .req_h_mem      ( tlp_h_mem ),
    .req_h_addr     ( tlp_h_addr ),
    .req_h_len      ( tlp_h_len ),
    .req_h_be_first ( tlp_h_be_first ),
    .req_h_be_last  ( tlp_h_be_last ),
    .req_h_token    ( rd_tlp_h_token ),
    .cpl_h_ready    ( rd_cpl_h_ready ),
    .cpl_h_valid    ( rd_cpl_h_valid ),
    .cpl_h_addr     ( rd_cpl_h_addr ),
    .cpl_h_len      ( rd_cpl_h_len ),
    .cpl_h_bytes    ( rd_cpl_h_bytes ),
    .cpl_h_last     ( rd_cpl_h_last ),
    .cpl_h_resp     ( rd_cpl_h_resp ),
    .cpl_d_ready    ( rd_cpl_d_ready ),
    .cpl_d_valid    ( rd_cpl_d_valid ),
    .cpl_d_data     ( rd_cpl_d_data ),
    .cpl_d_last     ( rd_cpl_d_last ),
    .axi_ar_ready   ( axi_ar_ready ),
    .axi_ar_valid   ( axi_ar_valid ),
    .axi_ar_addr    ( axi_ar_addr ),
    .axi_ar_len     ( axi_ar_len ),
    .axi_r_ready    ( axi_r_ready ),
    .axi_r_valid    ( axi_r_valid ),
    .axi_r_last     ( axi_r_last ),
    .axi_r_data     ( axi_r_data ),
    .axi_r_resp     ( axi_r_resp )
);


// ** TLP encode **

dlsc_pcie_s6_inbound_tlp dlsc_pcie_s6_inbound_tlp_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .rx_np_ok       ( rx_np_ok ),
    .tlp_id_ready   ( tlp_id_ready ),
    .tlp_id_valid   ( tlp_id_valid ),
    .tlp_id_write   ( tlp_id_write ),
    .tlp_id_data    ( tlp_id_data ),
    .wr_h_ready     ( wr_cpl_h_ready ),
    .wr_h_valid     ( wr_cpl_h_valid ),
    .wr_h_resp      ( wr_cpl_h_resp ),
    .rd_h_ready     ( rd_cpl_h_ready ),
    .rd_h_valid     ( rd_cpl_h_valid ),
    .rd_h_addr      ( rd_cpl_h_addr ),
    .rd_h_len       ( rd_cpl_h_len ),
    .rd_h_bytes     ( rd_cpl_h_bytes ),
    .rd_h_last      ( rd_cpl_h_last ),
    .rd_h_resp      ( rd_cpl_h_resp ),
    .rd_d_ready     ( rd_cpl_d_ready ),
    .rd_d_valid     ( rd_cpl_d_valid ),
    .rd_d_data      ( rd_cpl_d_data ),
    .rd_d_last      ( rd_cpl_d_last ),
    .tx_ready       ( tx_ready ),
    .tx_valid       ( tx_valid ),
    .tx_data        ( tx_data ),
    .tx_last        ( tx_last ),
    .bus_number     ( bus_number ),
    .dev_number     ( dev_number ),
    .func_number    ( func_number )
);


endmodule

