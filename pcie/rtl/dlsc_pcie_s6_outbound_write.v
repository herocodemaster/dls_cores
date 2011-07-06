
module dlsc_pcie_s6_outbound_write #(
    parameter ADDR      = 32,
    parameter LEN       = 4,
    parameter MAX_SIZE  = 128,
    parameter FCHB      = 8,
    parameter FCDB      = 12
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
    input   wire    [2:0]       max_payload_size,
    input   wire                dma_en,             // bus-mastering enabled
    
    // PCIe link partner credit info
    output  wire    [2:0]       fc_sel,             // selects 'transmit credits available'
    input   wire    [FCHB-1:0]  fc_ph,              // posted header credits
    input   wire    [FCDB-1:0]  fc_pd,              // posted data credits

    // TLP header to arbiter
    input   wire                wr_tlp_h_ready,
    output  wire                wr_tlp_h_valid,
    output  wire    [ADDR-1:2]  wr_tlp_h_addr,
    output  wire    [9:0]       wr_tlp_h_len,
    output  wire    [3:0]       wr_tlp_h_be_first,
    output  wire    [3:0]       wr_tlp_h_be_last,

    // TLP payload to arbiter
    input   wire                wr_tlp_d_ready,
    output  wire                wr_tlp_d_valid,
    output  wire    [31:0]      wr_tlp_d_data,
    output  wire                wr_tlp_d_last
);
    
wire            tlp_h_ready;
wire            tlp_h_valid;
wire [ADDR-1:2] tlp_h_addr;
wire [9:0]      tlp_h_len;
wire [3:0]      tlp_h_be_first;
wire [3:0]      tlp_h_be_last;

wire            tlp_d_ready;
wire            tlp_d_valid;
wire [31:0]     tlp_d_data;

dlsc_pcie_s6_outbound_write_core #(
    .ADDR               ( ADDR ),
    .LEN                ( LEN ),
    .MAX_SIZE           ( MAX_SIZE )
) dlsc_pcie_s6_outbound_write_core_inst (
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
    .tlp_h_ready        ( tlp_h_ready ),
    .tlp_h_valid        ( tlp_h_valid ),
    .tlp_h_addr         ( tlp_h_addr ),
    .tlp_h_len          ( tlp_h_len ),
    .tlp_h_be_first     ( tlp_h_be_first ),
    .tlp_h_be_last      ( tlp_h_be_last ),
    .tlp_d_ready        ( tlp_d_ready ),
    .tlp_d_valid        ( tlp_d_valid ),
    .tlp_d_data         ( tlp_d_data )
);

dlsc_pcie_s6_outbound_write_alloc #(
    .ADDR               ( ADDR ),
    .FCHB               ( FCHB ),
    .FCDB               ( FCDB )
) dlsc_pcie_s6_outbound_write_alloc_inst (
    .clk                ( clk ),
    .rst                ( rst ),
    .tlp_h_ready        ( tlp_h_ready ),
    .tlp_h_valid        ( tlp_h_valid ),
    .tlp_h_addr         ( tlp_h_addr ),
    .tlp_h_len          ( tlp_h_len ),
    .tlp_h_be_first     ( tlp_h_be_first ),
    .tlp_h_be_last      ( tlp_h_be_last ),
    .tlp_d_ready        ( tlp_d_ready ),
    .tlp_d_valid        ( tlp_d_valid ),
    .tlp_d_data         ( tlp_d_data ),
    .wr_tlp_h_ready     ( wr_tlp_h_ready ),
    .wr_tlp_h_valid     ( wr_tlp_h_valid ),
    .wr_tlp_h_addr      ( wr_tlp_h_addr ),
    .wr_tlp_h_len       ( wr_tlp_h_len ),
    .wr_tlp_h_be_first  ( wr_tlp_h_be_first ),
    .wr_tlp_h_be_last   ( wr_tlp_h_be_last ),
    .wr_tlp_d_ready     ( wr_tlp_d_ready ),
    .wr_tlp_d_valid     ( wr_tlp_d_valid ),
    .wr_tlp_d_data      ( wr_tlp_d_data ),
    .wr_tlp_d_last      ( wr_tlp_d_last ),
    .fc_sel             ( fc_sel ),
    .fc_ph              ( fc_ph ),
    .fc_pd              ( fc_pd ),
    .dma_en             ( dma_en )
);

endmodule

