
module dlsc_pcie_s6_outbound_write_core #(
    parameter ADDR      = 32,
    parameter LEN       = 4,
    parameter MOT       = 16,
    parameter MAX_SIZE  = 128                       // maximum write payload size (in bytes; power of 2)
) (
    // ** System **

    input   wire                clk,
    input   wire                rst,

    // ** AXI **

    // Write Command
    output  wire                axi_aw_ready,
    input   wire                axi_aw_valid,
    input   wire    [ADDR-1:0]  axi_aw_addr,
    input   wire    [LEN-1:0]   axi_aw_len,

    // Write Data
    output  wire                axi_w_ready,
    input   wire                axi_w_valid,
    input   wire                axi_w_last,
    input   wire    [3:0]       axi_w_strb,
    input   wire    [31:0]      axi_w_data,

    // Write Response
    input   wire                axi_b_ready,
    output  wire                axi_b_valid,
    output  wire    [1:0]       axi_b_resp,

    // ** PCIe **

    // Config
    input   wire    [2:0]       max_payload_size,   // 128, 256, 512, 1024, 2048, 4096

    // TLP header
    input   wire                tlp_h_ready,
    output  wire                tlp_h_valid,
    output  wire    [ADDR-1:2]  tlp_h_addr,
    output  wire    [9:0]       tlp_h_len,
    output  wire    [3:0]       tlp_h_be_first,
    output  wire    [3:0]       tlp_h_be_last,

    // TLP payload
    input   wire                tlp_d_ready,
    output  wire                tlp_d_valid,
    output  wire    [31:0]      tlp_d_data
);

`include "dlsc_clog2.vh"

// buffer is at least big enough to hold:
//  - 2 maximum size PCIe write payloads OR
//  - 2 maximum size AXI write payloads
localparam MAX_SIZE_BUFA    = `dlsc_clog2(MAX_SIZE/2);
localparam BUFA             = ((LEN+1) > MAX_SIZE_BUFA) ? (LEN+1) : MAX_SIZE_BUFA;


// ** Buffer AXI input **

wire            cmd_aw_ready;
wire            cmd_aw_valid;
wire [ADDR-1:2] cmd_aw_addr;
wire [LEN-1:0]  cmd_aw_len;

wire            cmd_w_ready;
wire            cmd_w_valid;
wire [3:0]      cmd_w_strb;

wire            tlp_d_axi_last;
wire            tlp_d_axi_ack   = (tlp_d_ready && tlp_d_valid && tlp_d_axi_last); // TODO

dlsc_pcie_s6_outbound_write_buffer #(
    .ADDR           ( ADDR ),
    .LEN            ( LEN ),
    .MOT            ( MOT ),
    .BUFA           ( BUFA )
) dlsc_pcie_s6_outbound_write_buffer_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .axi_aw_ready   ( axi_aw_ready ),
    .axi_aw_valid   ( axi_aw_valid ),
    .axi_aw_addr    ( axi_aw_addr ),
    .axi_aw_len     ( axi_aw_len ),
    .axi_w_ready    ( axi_w_ready ),
    .axi_w_valid    ( axi_w_valid ),
    .axi_w_last     ( axi_w_last ),
    .axi_w_strb     ( axi_w_strb ),
    .axi_w_data     ( axi_w_data ),
    .axi_b_ready    ( axi_b_ready ),
    .axi_b_valid    ( axi_b_valid ),
    .axi_b_resp     ( axi_b_resp ),
    .cmd_aw_ready   ( cmd_aw_ready ),
    .cmd_aw_valid   ( cmd_aw_valid ),
    .cmd_aw_addr    ( cmd_aw_addr ),
    .cmd_aw_len     ( cmd_aw_len ),
    .cmd_w_ready    ( cmd_w_ready ),
    .cmd_w_valid    ( cmd_w_valid ),
    .cmd_w_strb     ( cmd_w_strb ),
    .tlp_d_ready    ( tlp_d_ready ),
    .tlp_d_valid    ( tlp_d_valid ),
    .tlp_d_data     ( tlp_d_data ),
    .tlp_d_axi_last ( tlp_d_axi_last ),
    .tlp_d_axi_ack  ( tlp_d_axi_ack )
);


// ** Create command stream **

wire            cmd_ready;
wire            cmd_valid;
wire [ADDR-1:2] cmd_addr;
wire            cmd_addr_cont;
wire [3:0]      cmd_strb;
wire            cmd_last;

dlsc_pcie_s6_outbound_write_cmdsplit #(
    .ADDR           ( ADDR ),
    .LEN            ( LEN )
) dlsc_pcie_s6_outbound_write_cmdsplit_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .axi_aw_ready   ( cmd_aw_ready ),
    .axi_aw_valid   ( cmd_aw_valid ),
    .axi_aw_addr    ( cmd_aw_addr ),
    .axi_aw_len     ( cmd_aw_len ),
    .axi_w_ready    ( cmd_w_ready ),
    .axi_w_valid    ( cmd_w_valid ),
    .axi_w_strb     ( cmd_w_strb ),
    .cmd_ready      ( cmd_ready ),
    .cmd_valid      ( cmd_valid ),
    .cmd_addr       ( cmd_addr ),
    .cmd_addr_cont  ( cmd_addr_cont ),
    .cmd_strb       ( cmd_strb ),
    .cmd_last       ( cmd_last )
);


// ** Create TLP headers **

wire            tlp_ready;
wire            tlp_valid;
wire [ADDR-1:2] tlp_addr;
wire [9:0]      tlp_len;
wire [3:0]      tlp_be_first;
wire [3:0]      tlp_be_last;

dlsc_pcie_s6_outbound_write_cmdmerge #(
    .ADDR           ( ADDR ),
    .LEN            ( LEN ),
    .MAX_SIZE       ( MAX_SIZE )
) dlsc_pcie_s6_outbound_write_cmdmerge_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .cmd_ready      ( cmd_ready ),
    .cmd_valid      ( cmd_valid ),
    .cmd_addr       ( cmd_addr ),
    .cmd_addr_cont  ( cmd_addr_cont ),
    .cmd_strb       ( cmd_strb ),
    .cmd_last       ( cmd_last ),
    .tlp_ready      ( tlp_ready ),
    .tlp_valid      ( tlp_valid ),
    .tlp_addr       ( tlp_addr ),
    .tlp_len        ( tlp_len ),
    .tlp_be_first   ( tlp_be_first ),
    .tlp_be_last    ( tlp_be_last ),
    .max_payload_size ( max_payload_size )
);


// ** Buffer TLP headers **

dlsc_fifo_rvh #(
    .DATA           ( ADDR - 2 + 10 + 8 ),
    .DEPTH          ( 4 )
) dlsc_fifo_rvh_tlph (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_ready       ( tlp_ready ),
    .wr_valid       ( tlp_valid ),
    .wr_data        ( {
        tlp_addr,
        tlp_len,
        tlp_be_first,
        tlp_be_last } ),
    .wr_almost_full (  ),
    .rd_ready       ( tlp_h_ready ),
    .rd_valid       ( tlp_h_valid ),
    .rd_data        ( {
        tlp_h_addr,
        tlp_h_len,
        tlp_h_be_first,
        tlp_h_be_last } ),
    .rd_almost_empty(  )
);


endmodule

