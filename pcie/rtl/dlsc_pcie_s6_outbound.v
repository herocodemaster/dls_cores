
module dlsc_pcie_s6_outbound #(
    parameter ADDR          = 32,       // width of AXI address bus
    parameter LEN           = 4,        // width of AXI length field
    parameter TAG           = 5,        // PCIe tag bits
    parameter WRITE_SIZE    = 128,      // max write size (in bytes; power of 2)
    parameter READ_MOT      = 16,       // max outstanding read transactions
    parameter READ_SIZE     = 2048,     // size of read buffer (in bytes; power of 2)
    parameter READ_CPLH     = 8,        // max receive buffer completion header space
    parameter READ_CPLD     = 64,       // max receive buffer completion data space    
    parameter READ_TIMEOUT  = 625000,   // read completion timeout (default is 10ms at 62.5 MHz)
    parameter FCHB          = 8,        // bits for flow control header credits
    parameter FCDB          = 12        // bits for flow control data credits
) (
    // ** System **

    input   wire                clk,
    input   wire                rst,
    
    // ** AXI **

    // Read Command
    output  wire                axi_ar_ready,
    input   wire                axi_ar_valid,
    input   wire    [ADDR-1:0]  axi_ar_addr,
    input   wire    [LEN-1:0]   axi_ar_len,

    // Read response
    input   wire                axi_r_ready,
    output  wire                axi_r_valid,
    output  wire                axi_r_last,
    output  wire    [31:0]      axi_r_data,
    output  wire    [1:0]       axi_r_resp,
    
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

    // Status
    output  wire                tlp_pending,        // transactions pending

    // Config
    input   wire    [2:0]       max_payload_size,
    input   wire    [2:0]       max_read_request,
    input   wire                rcb,                // read completion boundary
    input   wire                dma_en,             // bus-mastering enabled
    
    // PCIe ID
    input   wire    [7:0]       bus_number,
    input   wire    [4:0]       dev_number,
    input   wire    [2:0]       func_number,
    
    // PCIe link partner credit info
    output  wire    [2:0]       fc_sel,             // selects 'transmit credits available'
    input   wire    [FCHB-1:0]  fc_ph,              // posted header credits
    input   wire    [FCDB-1:0]  fc_pd,              // posted data credits

    // TLP receive input (completions only)
    output  wire                rx_ready,
    input   wire                rx_valid,
    input   wire    [31:0]      rx_data,
    input   wire                rx_last,
    input   wire                rx_err,
    
    // TLP output
    input   wire                tx_ready,
    output  wire                tx_valid,
    output  wire    [31:0]      tx_data,
    output  wire                tx_last,

    // Error reporting
    input   wire                err_ready,
    output  wire                err_valid,
    output  wire                err_unexpected,
    output  wire                err_timeout
);

`include "dlsc_clog2.vh"


// ** Read **

localparam READ_BUFA = `dlsc_clog2(READ_SIZE/4);
    
wire            rd_tlp_h_ready;
wire            rd_tlp_h_valid;
wire [ADDR-1:2] rd_tlp_h_addr;
wire [9:0]      rd_tlp_h_len;
wire [TAG-1:0]  rd_tlp_h_tag;
wire [3:0]      rd_tlp_h_be_first;
wire [3:0]      rd_tlp_h_be_last;

dlsc_pcie_s6_outbound_read #(
    .ADDR               ( ADDR ),
    .LEN                ( LEN ),
    .MOT                ( READ_MOT ),
    .BUFA               ( READ_BUFA ),
    .TAG                ( TAG ),
    .CPLH               ( READ_CPLH ),
    .CPLD               ( READ_CPLD ),
    .FCHB               ( FCHB ),
    .FCDB               ( FCDB ),
    .TIMEOUT            ( READ_TIMEOUT )
) dlsc_pcie_s6_outbound_read_inst (
    .clk                ( clk ),
    .rst                ( rst ),
    .axi_ar_ready       ( axi_ar_ready ),
    .axi_ar_valid       ( axi_ar_valid ),
    .axi_ar_addr        ( axi_ar_addr ),
    .axi_ar_len         ( axi_ar_len ),
    .axi_r_ready        ( axi_r_ready ),
    .axi_r_valid        ( axi_r_valid ),
    .axi_r_last         ( axi_r_last ),
    .axi_r_data         ( axi_r_data ),
    .axi_r_resp         ( axi_r_resp ),
    .tlp_pending        ( tlp_pending ),
    .max_read_request   ( max_read_request ),
    .rcb                ( rcb ),
    .dma_en             ( dma_en ),
    .rx_ready           ( rx_ready ),
    .rx_valid           ( rx_valid ),
    .rx_data            ( rx_data ),
    .rx_last            ( rx_last ),
    .rx_err             ( rx_err ),
    .rd_tlp_h_ready     ( rd_tlp_h_ready ),
    .rd_tlp_h_valid     ( rd_tlp_h_valid ),
    .rd_tlp_h_addr      ( rd_tlp_h_addr ),
    .rd_tlp_h_len       ( rd_tlp_h_len ),
    .rd_tlp_h_tag       ( rd_tlp_h_tag ),
    .rd_tlp_h_be_first  ( rd_tlp_h_be_first ),
    .rd_tlp_h_be_last   ( rd_tlp_h_be_last ),
    .err_ready          ( err_ready ),
    .err_valid          ( err_valid ),
    .err_unexpected     ( err_unexpected ),
    .err_timeout        ( err_timeout )
);


// ** Write **

wire            wr_tlp_h_ready;
wire            wr_tlp_h_valid;
wire [ADDR-1:2] wr_tlp_h_addr;
wire [9:0]      wr_tlp_h_len;
wire [3:0]      wr_tlp_h_be_first;
wire [3:0]      wr_tlp_h_be_last;
wire            wr_tlp_d_ready;
wire            wr_tlp_d_valid;
wire [31:0]     wr_tlp_d_data;

dlsc_pcie_s6_outbound_write #(
    .ADDR               ( ADDR ),
    .LEN                ( LEN ),
    .MAX_SIZE           ( WRITE_SIZE ),
    .FCHB               ( FCHB ),
    .FCDB               ( FCDB )
) dlsc_pcie_s6_outbound_write_inst (
    .clk                ( clk ),
    .rst                ( rst ),
    .axi_aw_ready       ( axi_aw_ready ),
    .axi_aw_valid       ( axi_aw_valid ),
    .axi_aw_addr        ( axi_aw_addr ),
    .axi_aw_len         ( axi_aw_len ),
    .axi_w_ready        ( axi_w_ready ),
    .axi_w_valid        ( axi_w_valid ),
    .axi_w_last         ( axi_w_last ),
    .axi_w_strb         ( axi_w_strb ),
    .axi_w_data         ( axi_w_data ),
    .axi_b_ready        ( axi_b_ready ),
    .axi_b_valid        ( axi_b_valid ),
    .axi_b_resp         ( axi_b_resp ),
    .max_payload_size   ( max_payload_size ),
    .dma_en             ( dma_en ),
    .fc_sel             ( fc_sel ),
    .fc_ph              ( fc_ph ),
    .fc_pd              ( fc_pd ),
    .wr_tlp_h_ready     ( wr_tlp_h_ready ),
    .wr_tlp_h_valid     ( wr_tlp_h_valid ),
    .wr_tlp_h_addr      ( wr_tlp_h_addr ),
    .wr_tlp_h_len       ( wr_tlp_h_len ),
    .wr_tlp_h_be_first  ( wr_tlp_h_be_first ),
    .wr_tlp_h_be_last   ( wr_tlp_h_be_last ),
    .wr_tlp_d_ready     ( wr_tlp_d_ready ),
    .wr_tlp_d_valid     ( wr_tlp_d_valid ),
    .wr_tlp_d_data      ( wr_tlp_d_data )
);


// ** Address Translator (TODO) **

wire            trans_req;
wire [ADDR-1:2] trans_req_addr;
wire            trans_ack       = trans_req;
wire [63:2]     trans_ack_addr  = { {(64-ADDR){1'b0}}, trans_req_addr[ADDR-1:2] };
wire            trans_ack_64    = 1'b0;


// ** TLP **

dlsc_pcie_s6_outbound_tlp #(
    .ADDR               ( ADDR ),
    .TAG                ( TAG )
) dlsc_pcie_s6_outbound_tlp_inst (
    .clk                ( clk ),
    .rst                ( rst ),
    .trans_req          ( trans_req ),
    .trans_req_addr     ( trans_req_addr ),
    .trans_ack          ( trans_ack ),
    .trans_ack_addr     ( trans_ack_addr ),
    .trans_ack_64       ( trans_ack_64 ),
    .rd_tlp_h_ready     ( rd_tlp_h_ready ),
    .rd_tlp_h_valid     ( rd_tlp_h_valid ),
    .rd_tlp_h_addr      ( rd_tlp_h_addr ),
    .rd_tlp_h_len       ( rd_tlp_h_len ),
    .rd_tlp_h_tag       ( rd_tlp_h_tag ),
    .rd_tlp_h_be_first  ( rd_tlp_h_be_first ),
    .rd_tlp_h_be_last   ( rd_tlp_h_be_last ),
    .wr_tlp_h_ready     ( wr_tlp_h_ready ),
    .wr_tlp_h_valid     ( wr_tlp_h_valid ),
    .wr_tlp_h_addr      ( wr_tlp_h_addr ),
    .wr_tlp_h_len       ( wr_tlp_h_len ),
    .wr_tlp_h_be_first  ( wr_tlp_h_be_first ),
    .wr_tlp_h_be_last   ( wr_tlp_h_be_last ),
    .wr_tlp_d_ready     ( wr_tlp_d_ready ),
    .wr_tlp_d_valid     ( wr_tlp_d_valid ),
    .wr_tlp_d_data      ( wr_tlp_d_data ),
    .tlp_ready          ( tx_ready ),
    .tlp_valid          ( tx_valid ),
    .tlp_data           ( tx_data ),
    .tlp_last           ( tx_last ),
    .bus_number         ( bus_number ),
    .dev_number         ( dev_number ),
    .func_number        ( func_number )
);

endmodule

