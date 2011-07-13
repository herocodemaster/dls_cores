
module dlsc_pcie_s6_outbound_read #(
    parameter ADDR      = 32,
    parameter LEN       = 4,
    parameter MOT       = 16,       // max outstanding read transactions
    parameter BUFA      = 9,        // receive buffer is 2**BUFA words deep
    parameter TAG       = 5,        // PCIe tag bits
    parameter CPLH      = 8,        // receive buffer completion header space
    parameter CPLD      = 64,       // receive buffer completion data space    
    parameter FCHB      = 8,        // bits for CPLH
    parameter FCDB      = 12,       // bits for CPLD
    parameter TIMEOUT   = 625000    // read completion timeout (default is 10ms at 62.5 MHz)
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

    // ** PCIe **

    // Status
    output  wire                tlp_pending,        // transactions pending

    // Config
    input   wire    [2:0]       max_read_request,
    input   wire                rcb,                // read completion boundary
    input   wire                dma_en,             // bus-mastering enabled

    // TLP receive input (completions only)
    output  wire                rx_ready,
    input   wire                rx_valid,
    input   wire    [31:0]      rx_data,
    input   wire                rx_last,
    input   wire                rx_err,

    // TLP output to arbiter
    input   wire                rd_tlp_h_ready,
    output  wire                rd_tlp_h_valid,
    output  wire    [ADDR-1:2]  rd_tlp_h_addr,
    output  wire    [9:0]       rd_tlp_h_len,
    output  wire    [TAG-1:0]   rd_tlp_h_tag,
    output  wire    [3:0]       rd_tlp_h_be_first,
    output  wire    [3:0]       rd_tlp_h_be_last,

    // Error reporting
    input   wire                err_ready,
    output  wire                err_valid,
    output  wire                err_unexpected,
    output  wire                err_timeout
);

localparam  MAX_SIZE = (2**BUFA)*4;


// ** Decouple AR **

wire            axi_ar_ready_r;
wire            axi_ar_valid_r;
wire [ADDR-1:0] axi_ar_addr_r;
wire [LEN-1:0]  axi_ar_len_r;

wire            axi_ar_ready_rbi;
wire            axi_ar_valid_rbi;

wire            axi_ar_ready_rri;
wire            axi_ar_valid_rri;

assign          axi_ar_valid_rbi    = axi_ar_valid_r && axi_ar_ready_rri;
assign          axi_ar_valid_rri    = axi_ar_valid_r && axi_ar_ready_rbi;

assign          axi_ar_ready_r      = axi_ar_ready_rri && axi_ar_ready_rbi;

dlsc_rvh_decoupler #(
    .WIDTH              ( ADDR + LEN )
) dlsc_rvh_decoupler_ar (
    .clk                ( clk ),
    .rst                ( rst ),
    .in_en              ( 1'b1 ),
    .in_ready           ( axi_ar_ready ),
    .in_valid           ( axi_ar_valid ),
    .in_data            ( { axi_ar_addr, axi_ar_len } ),
    .out_en             ( 1'b1 ),
    .out_ready          ( axi_ar_ready_r ),
    .out_valid          ( axi_ar_valid_r ),
    .out_data           ( { axi_ar_addr_r, axi_ar_len_r } )
);


// ** Signals **

// alloc -> cpl, buffer
wire            alloc_init;
wire            alloc_valid;
wire [TAG:0]    alloc_tag;
wire [9:0]      alloc_len;
wire [6:2]      alloc_addr;
wire [BUFA:0]   alloc_bufa;

// cpl -> buffer
wire            cpl_ready;
wire            cpl_valid;
wire            cpl_last;
wire [31:0]     cpl_data;
wire [1:0]      cpl_resp;
wire [TAG-1:0]  cpl_tag;

// cpl -> alloc
wire            dealloc_cplh;
wire            dealloc_cpld;
// buffer -> alloc
wire            dealloc_tag;
wire            dealloc_data;

// req -> alloc
wire            tlp_h_ready;
wire            tlp_h_valid;
wire [ADDR-1:2] tlp_h_addr;
wire [9:0]      tlp_h_len;


// ** Completion Buffer **

dlsc_pcie_s6_outbound_read_buffer #(
    .LEN                ( LEN ),
    .TAG                ( TAG ),
    .BUFA               ( BUFA ),
    .MOT                ( MOT )
) dlsc_pcie_s6_outbound_read_buffer_inst (
    .clk                ( clk ),
    .rst                ( rst ),
    .axi_ar_ready       ( axi_ar_ready_rbi ),
    .axi_ar_valid       ( axi_ar_valid_rbi ),
    .axi_ar_len         ( axi_ar_len_r ),
    .axi_r_ready        ( axi_r_ready ),
    .axi_r_valid        ( axi_r_valid ),
    .axi_r_last         ( axi_r_last ),
    .axi_r_data         ( axi_r_data ),
    .axi_r_resp         ( axi_r_resp ),
    .cpl_ready          ( cpl_ready ),
    .cpl_valid          ( cpl_valid ),
    .cpl_last           ( cpl_last ),
    .cpl_data           ( cpl_data ),
    .cpl_resp           ( cpl_resp ),
    .cpl_tag            ( cpl_tag ),
    .alloc_init         ( alloc_init ),
    .alloc_valid        ( alloc_valid ),
    .alloc_tag          ( alloc_tag ),
    .alloc_bufa         ( alloc_bufa ),
    .dealloc_tag        ( dealloc_tag ),
    .dealloc_data       ( dealloc_data )
);


// ** Request Generator **

dlsc_pcie_s6_outbound_read_req #(
    .ADDR               ( ADDR ),
    .LEN                ( LEN ),
    .MAX_SIZE           ( MAX_SIZE )
) dlsc_pcie_s6_outbound_read_req_inst (
    .clk                ( clk ),
    .rst                ( rst ),
    .axi_ar_ready       ( axi_ar_ready_rri ),
    .axi_ar_valid       ( axi_ar_valid_rri ),
    .axi_ar_addr        ( axi_ar_addr_r ),
    .axi_ar_len         ( axi_ar_len_r ),
    .max_read_request   ( max_read_request ),
    .tlp_h_ready        ( tlp_h_ready ),
    .tlp_h_valid        ( tlp_h_valid ),
    .tlp_h_addr         ( tlp_h_addr ),
    .tlp_h_len          ( tlp_h_len )
);


// ** Request Allocator **

dlsc_pcie_s6_outbound_read_alloc #(
    .ADDR               ( ADDR ),
    .TAG                ( TAG ),
    .BUFA               ( BUFA ),
    .CPLH               ( CPLH ),
    .CPLD               ( CPLD ),
    .FCHB               ( FCHB ),
    .FCDB               ( FCDB )
) dlsc_pcie_s6_outbound_read_alloc_inst (
    .clk                ( clk ),
    .rst                ( rst ),
    .alloc_init         ( alloc_init ),
    .alloc_valid        ( alloc_valid ),
    .alloc_tag          ( alloc_tag ),
    .alloc_len          ( alloc_len ),
    .alloc_addr         ( alloc_addr ),
    .alloc_bufa         ( alloc_bufa ),
    .dealloc_cplh       ( dealloc_cplh ),
    .dealloc_cpld       ( dealloc_cpld ),
    .dealloc_tag        ( dealloc_tag ),
    .dealloc_data       ( dealloc_data ),
    .tlp_h_ready        ( tlp_h_ready ),
    .tlp_h_valid        ( tlp_h_valid ),
    .tlp_h_addr         ( tlp_h_addr ),
    .tlp_h_len          ( tlp_h_len ),
    .rd_tlp_h_ready     ( rd_tlp_h_ready ),
    .rd_tlp_h_valid     ( rd_tlp_h_valid ),
    .rd_tlp_h_addr      ( rd_tlp_h_addr ),
    .rd_tlp_h_len       ( rd_tlp_h_len ),
    .rd_tlp_h_tag       ( rd_tlp_h_tag ),
    .rd_tlp_h_be_first  ( rd_tlp_h_be_first ),
    .rd_tlp_h_be_last   ( rd_tlp_h_be_last ),
    .tlp_pending        ( tlp_pending ),
    .dma_en             ( dma_en ),
    .rcb                ( rcb )
);


// ** Request Completer **

dlsc_pcie_s6_outbound_read_cpl #(
    .TAG                ( TAG ),
    .TIMEOUT            ( TIMEOUT )
) dlsc_pcie_s6_outbound_read_cpl_inst (
    .clk                ( clk ),
    .rst                ( rst ),
    .rx_ready           ( rx_ready ),
    .rx_valid           ( rx_valid ),
    .rx_data            ( rx_data ),
    .rx_last            ( rx_last ),
    .rx_err             ( rx_err ),
    .err_ready          ( err_ready ),
    .err_valid          ( err_valid ),
    .err_unexpected     ( err_unexpected ),
    .err_timeout        ( err_timeout ),
    .cpl_ready          ( cpl_ready ),
    .cpl_valid          ( cpl_valid ),
    .cpl_last           ( cpl_last ),
    .cpl_data           ( cpl_data ),
    .cpl_resp           ( cpl_resp ),
    .cpl_tag            ( cpl_tag ),
    .alloc_init         ( alloc_init ),
    .alloc_valid        ( alloc_valid ),
    .alloc_tag          ( alloc_tag ),
    .alloc_len          ( alloc_len ),
    .alloc_addr         ( alloc_addr ),
    .dealloc_tag        ( dealloc_tag ),
    .dealloc_cplh       ( dealloc_cplh ),
    .dealloc_cpld       ( dealloc_cpld ),
    .rcb                ( rcb )
);



endmodule

