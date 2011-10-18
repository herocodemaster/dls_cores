
module dlsc_pcie_s6_inbound #(
    // ** Clock relationships **
    parameter APB_CLK_DOMAIN    = 0,
    parameter IB_CLK_DOMAIN     = 0,

    // ** APB **
    parameter APB_EN            = 1,                // enable APB registers and interrupts

    // ** Inbound **
    parameter ADDR              = 32,               // width of AXI address bus
    parameter LEN               = 4,                // width of AXI length field
    parameter WRITE_EN          = 1,                // enable inbound write path
    parameter WRITE_BUFFER      = 32,
    parameter WRITE_MOT         = 16,               // max outstanding write transactions
    parameter READ_EN           = 1,                // enable inbound read path
    parameter READ_BUFFER       = 256,
    parameter READ_MOT          = 16,               // max outstanding read transactions

    // Address translation
    parameter [ADDR-1:0] TRANS_BAR0_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_BAR0_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_BAR1_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_BAR1_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_BAR2_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_BAR2_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_BAR3_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_BAR3_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_BAR4_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_BAR4_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_BAR5_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_BAR5_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_ROM_MASK  = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_ROM_BASE  = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_CFG_MASK  = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_CFG_BASE  = {ADDR{1'b0}}
) (
    // ** APB **
    
    // System
    input   wire                apb_clk,
    input   wire                apb_rst,

    // Control/Status
    input   wire                apb_ib_rd_disable,
    input   wire                apb_ib_wr_disable,
    output  wire                apb_ib_rd_busy,
    output  wire                apb_ib_wr_busy,

    // ** AXI **
    
    // System
    input   wire                axi_clk,        // == pcie_clk when !ASYNC
    input   wire                axi_rst,        // == pcie_rst when !ASYNC
    
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

    // System
    input   wire                pcie_clk,
    input   wire                pcie_rst,

    // Status
    output  wire                pcie_rx_np_ok,
    
    // Config
    input   wire    [2:0]       pcie_max_payload_size,
    
    // PCIe ID
    input   wire    [7:0]       pcie_bus_number,
    input   wire    [4:0]       pcie_dev_number,
    input   wire    [2:0]       pcie_func_number,

    // TLP receive input (requests only)
    output  wire                pcie_rx_ready,
    input   wire                pcie_rx_valid,
    input   wire    [31:0]      pcie_rx_data,
    input   wire                pcie_rx_last,
    input   wire                pcie_rx_err,
    input   wire    [6:0]       pcie_rx_bar,

    // TLP output
    input   wire                pcie_tx_ready,
    output  wire                pcie_tx_valid,
    output  wire    [31:0]      pcie_tx_data,
    output  wire                pcie_tx_last,
    output  wire                pcie_tx_error,

    // Error reporting
    input   wire                pcie_err_ready,
    output  wire                pcie_err_valid,
    output  wire                pcie_err_unsupported
);

`include "dlsc_clog2.vh"

localparam  WRITE_BUFA          = `dlsc_clog2(WRITE_BUFFER);
localparam  READ_BUFA           = `dlsc_clog2(READ_BUFFER);

localparam  TOKN                = 6;


// ** Synchronized PCIe signals **
    
wire            rx_np_ok_rd;
wire            rx_np_ok_tlp;
wire            rx_np_ok = rx_np_ok_rd && rx_np_ok_tlp;

// Config
wire [2:0]      max_payload_size;

// PCIe ID
wire [7:0]      bus_number;
wire [4:0]      dev_number;
wire [2:0]      func_number;

// TLP receive input (requests only)
wire            rx_ready;
wire            rx_valid;
wire [31:0]     rx_data;
wire            rx_last;
wire            rx_err;
wire [6:0]      rx_bar;

// TLP output
wire            tx_ready;
wire            tx_valid;
wire [31:0]     tx_data;
wire            tx_last;
wire            tx_error;

// Error reporting
wire            err_ready;
wire            err_valid;
wire            err_unsupported;

// Local control
wire            bridge_rst;
wire            axi_disable;
wire            axi_flush;
wire            rd_disable;
wire            wr_disable;
wire            rd_busy;
wire            wr_busy;

generate
if(APB_EN) begin:GEN_APB

    if(APB_CLK_DOMAIN!=IB_CLK_DOMAIN) begin:GEN_APB_ASYNC

        dlsc_syncflop #(
            .DATA       ( 2 ),
            .RESET      ( 2'b11 )
        ) dlsc_syncflop_disable (
            .in         ( { apb_ib_rd_disable, apb_ib_wr_disable } ),
            .clk        ( axi_clk ),
            .rst        ( bridge_rst ),
            .out        ( {        rd_disable,        wr_disable } )
        );
        
        dlsc_syncflop #(
            .DATA       ( 2 ),
            .RESET      ( 2'b11 )
        ) dlsc_syncflop_busy (
            .in         ( {        rd_busy,        wr_busy } ),
            .clk        ( apb_clk ),
            .rst        ( apb_rst ),
            .out        ( { apb_ib_rd_busy, apb_ib_wr_busy } )
        );

    end else begin:GEN_APB_SYNC

        assign          rd_disable          = apb_ib_rd_disable;
        assign          wr_disable          = apb_ib_wr_disable;
        assign          apb_ib_rd_busy      = rd_busy;
        assign          apb_ib_wr_busy      = wr_busy;

    end

end else begin:GEN_NO_APB
    
    assign          rd_disable          = 1'b0;
    assign          wr_disable          = 1'b0;
    assign          apb_ib_rd_busy      = 1'b0;
    assign          apb_ib_wr_busy      = 1'b0;

end

if(IB_CLK_DOMAIN!=0) begin:GEN_SYNC
    
    assign          pcie_rx_np_ok       = rx_np_ok;

    assign          max_payload_size    = pcie_max_payload_size;

    assign          bus_number          = pcie_bus_number;
    assign          dev_number          = pcie_dev_number;
    assign          func_number         = pcie_func_number;

    assign          pcie_rx_ready       = rx_ready;
    assign          rx_valid            = pcie_rx_valid;
    assign          rx_data             = pcie_rx_data;
    assign          rx_last             = pcie_rx_last;
    assign          rx_err              = pcie_rx_err;
    assign          rx_bar              = pcie_rx_bar;

    assign          tx_ready            = pcie_tx_ready;
    assign          pcie_tx_valid       = tx_valid;
    assign          pcie_tx_data        = tx_data;
    assign          pcie_tx_last        = tx_last;
    assign          pcie_tx_error       = tx_error;

    assign          err_ready           = pcie_err_ready;
    assign          pcie_err_valid      = err_valid;
    assign          pcie_err_unsupported = err_unsupported;

    assign          bridge_rst          = pcie_rst;
    assign          axi_disable         = 1'b0;
    assign          axi_flush           = 1'b0;

end else begin:GEN_ASYNC

    wire            cross_rst;

    dlsc_pcie_s6_rstcontrol dlsc_pcie_s6_rstcontrol_inst (
        .pcie_rst       ( pcie_rst ),
        .clk            ( axi_clk ),
        .rst            ( axi_rst ),
        .cross_rst      ( cross_rst ),
        .bridge_rst     ( bridge_rst ),
        .axi_busy       ( rd_busy || wr_busy ),
        .axi_disable    ( axi_disable ),
        .axi_flush      ( axi_flush )
    );

    // status to PCIe controller
    dlsc_syncflop #(
        .DATA           ( 1 ),
        .RESET          ( 1'b0 )
    ) dlsc_syncflop_rx_np_ok (
        .in             ( rx_np_ok ),
        .clk            ( pcie_clk ),
        .rst            ( pcie_rst ),
        .out            ( pcie_rx_np_ok )
    );

    // config from PCIe controller
    dlsc_domaincross #(
        .DATA           ( 3+8+5+3 )
    ) dlsc_domaincross_inst (
        .in_clk         ( pcie_clk ),
        .in_rst         ( pcie_rst ),
        .in_data        ( {
            pcie_max_payload_size,
            pcie_bus_number,
            pcie_dev_number,
            pcie_func_number } ),
        .out_clk        ( axi_clk ),
        .out_rst        ( cross_rst ),
        .out_data       ( {
            max_payload_size,
            bus_number,
            dev_number,
            func_number } )
    );

    // TLPs to PCIe controller
    dlsc_pcie_s6_tlpfifo #(
        .DATA           ( 33 ),
        .ADDR           ( 4 )
    ) dlsc_pcie_s6_tlpfifo_tx (
        .wr_clk         ( axi_clk ),
        .wr_rst         ( cross_rst ),
        .wr_ready       ( tx_ready ),
        .wr_valid       ( tx_valid && !axi_disable ),
        .wr_last        ( tx_last ),
        .wr_data        ( { tx_error, tx_data } ),
        .rd_clk         ( pcie_clk ),
        .rd_rst         ( pcie_rst ),
        .rd_ready       ( pcie_tx_ready ),
        .rd_valid       ( pcie_tx_valid ),
        .rd_last        ( pcie_tx_last ),
        .rd_data        ( { pcie_tx_error, pcie_tx_data } )
    );

    // TLPs from PCIe controller
    dlsc_pcie_s6_tlpfifo #(
        .DATA           ( 7+1+32 ),
        .ADDR           ( 4 )
    ) dlsc_fifo_s6_tlpfifo_rx (
        .wr_clk         ( pcie_clk ),
        .wr_rst         ( pcie_rst ),
        .wr_ready       ( pcie_rx_ready ),
        .wr_valid       ( pcie_rx_valid ),
        .wr_last        ( pcie_rx_last ),
        .wr_data        ( { pcie_rx_bar, pcie_rx_err, pcie_rx_data } ),
        .rd_clk         ( axi_clk ),
        .rd_rst         ( cross_rst ),
        .rd_ready       ( rx_ready ),
        .rd_valid       ( rx_valid ),
        .rd_last        ( rx_last ),
        .rd_data        ( { rx_bar, rx_err, rx_data } )
    );

    if(WRITE_EN!=0) begin:GEN_ASYNC_WRITE

        // Errors to PCIe controller
        // (only used by write path)
        dlsc_domaincross_rvh #(
            .DATA           ( 1 ),
            .RESET          ( 1'b0 ),
            .RESET_ON_TRANSFER ( 1 )
        ) dlsc_domaincross_rvh_err (
            .in_clk         ( axi_clk ),
            .in_rst         ( cross_rst ),
            .in_ready       ( err_ready ),
            .in_valid       ( err_valid && !axi_disable ),
            .in_data        ( { err_unsupported } ),
            .out_clk        ( pcie_clk ),
            .out_rst        ( pcie_rst ),
            .out_ready      ( pcie_err_ready ),
            .out_valid      ( pcie_err_valid ),
            .out_data       ( { pcie_err_unsupported } )
        );
    
    end else begin:GEN_ASYNC_NOWRITE

        assign          err_ready           = 1'b0;
        assign          pcie_err_valid      = 1'b0;
        assign          pcie_err_unsupported = 1'b0;

    end

end
endgenerate


// ** Address Translator **
    
wire            trans_req;
wire [2:0]      trans_req_bar;
wire [63:2]     trans_req_addr;
wire            trans_req_64;
wire            trans_ack;
wire [ADDR-1:2] trans_ack_addr;

dlsc_pcie_s6_inbound_trans #(
    .ADDR           ( ADDR ),
    .TRANS_BAR0_MASK ( TRANS_BAR0_MASK ),
    .TRANS_BAR0_BASE ( TRANS_BAR0_BASE ),
    .TRANS_BAR1_MASK ( TRANS_BAR1_MASK ),
    .TRANS_BAR1_BASE ( TRANS_BAR1_BASE ),
    .TRANS_BAR2_MASK ( TRANS_BAR2_MASK ),
    .TRANS_BAR2_BASE ( TRANS_BAR2_BASE ),
    .TRANS_BAR3_MASK ( TRANS_BAR3_MASK ),
    .TRANS_BAR3_BASE ( TRANS_BAR3_BASE ),
    .TRANS_BAR4_MASK ( TRANS_BAR4_MASK ),
    .TRANS_BAR4_BASE ( TRANS_BAR4_BASE ),
    .TRANS_BAR5_MASK ( TRANS_BAR5_MASK ),
    .TRANS_BAR5_BASE ( TRANS_BAR5_BASE ),
    .TRANS_ROM_MASK ( TRANS_ROM_MASK ),
    .TRANS_ROM_BASE ( TRANS_ROM_BASE ),
    .TRANS_CFG_MASK ( TRANS_CFG_MASK ),
    .TRANS_CFG_BASE ( TRANS_CFG_BASE )
) dlsc_pcie_s6_inbound_trans_inst (
    .clk            ( axi_clk ),
    .rst            ( bridge_rst ),
    .trans_req      ( trans_req ),
    .trans_req_bar  ( trans_req_bar ),
    .trans_req_addr ( trans_req_addr ),
    .trans_req_64   ( trans_req_64 ),
    .trans_ack      ( trans_ack ),
    .trans_ack_addr ( trans_ack_addr )
);


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
    .clk            ( axi_clk ),
    .rst            ( bridge_rst ),
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
    .clk            ( axi_clk ),
    .rst            ( bridge_rst ),
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

generate
if(WRITE_EN) begin:GEN_WRITE

    dlsc_pcie_s6_inbound_write #(
        .ADDR           ( ADDR ),
        .LEN            ( LEN ),
        .BUFA           ( WRITE_BUFA ),
        .MOT            ( WRITE_MOT ),
        .TOKN           ( TOKN )
    ) dlsc_pcie_s6_inbound_write_inst (
        .clk            ( axi_clk ),
        .rst            ( bridge_rst ),
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
        .axi_b_resp     ( axi_b_resp ),
        .wr_busy        ( wr_busy ),
        .wr_disable     ( axi_disable || wr_disable ),
        .wr_flush       ( axi_flush )
    );

end else begin:GEN_NOWRITE

    assign          token_wr            = 0;

    assign          wr_tlp_h_ready      = 1'b0;

    assign          tlp_d_ready         = 1'b0;

    assign          wr_cpl_h_valid      = 1'b0;
    assign          wr_cpl_h_resp       = 2'b00;

    assign          err_valid           = 1'b0;
    assign          err_unsupported     = 1'b0;

    assign          axi_aw_valid        = 1'b0;
    assign          axi_aw_addr         = {ADDR{1'b0}};
    assign          axi_aw_len          = {LEN{1'b0}};

    assign          axi_w_valid         = 1'b0;
    assign          axi_w_last          = 1'b0;
    assign          axi_w_data          = 32'd0;
    assign          axi_w_strb          = 4'd0;

    assign          axi_b_ready         = 1'b0;

    assign          wr_busy             = 1'b0;

end
endgenerate


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

generate
if(READ_EN) begin:GEN_READ

    dlsc_pcie_s6_inbound_read #(
        .ADDR           ( ADDR ),
        .LEN            ( LEN ),
        .BUFA           ( READ_BUFA ),
        .MOT            ( READ_MOT ),
        .TOKN           ( TOKN )
    ) dlsc_pcie_s6_inbound_read_inst (
        .clk            ( axi_clk ),
        .rst            ( bridge_rst ),
        .rx_np_ok       ( rx_np_ok_rd ),
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
        .axi_r_resp     ( axi_r_resp ),
        .rd_busy        ( rd_busy ),
        .rd_disable     ( axi_disable || rd_disable ),
        .rd_flush       ( axi_flush )
    );

end else begin:GEN_NOREAD

    assign          rx_np_ok_rd         = 1'b1;

    assign          token_oldest        = token_wr;

    assign          rd_tlp_h_ready      = 1'b0;

    assign          rd_cpl_h_valid      = 1'b0;
    assign          rd_cpl_h_addr       = 7'd0;
    assign          rd_cpl_h_len        = 10'd0;
    assign          rd_cpl_h_bytes      = 12'd0;
    assign          rd_cpl_h_last       = 1'b0;
    assign          rd_cpl_h_resp       = 2'b00;

    assign          rd_cpl_d_valid      = 1'b0;
    assign          rd_cpl_d_data       = 32'd0;
    assign          rd_cpl_d_last       = 1'b0;

    assign          axi_ar_valid        = 1'b0;
    assign          axi_ar_addr         = {ADDR{1'b0}};
    assign          axi_ar_len          = {LEN{1'b0}};

    assign          axi_r_ready         = 1'b0;
    
    assign          rd_busy             = 1'b0;

end
endgenerate


// ** TLP encode **

dlsc_pcie_s6_inbound_tlp dlsc_pcie_s6_inbound_tlp_inst (
    .clk            ( axi_clk ),
    .rst            ( bridge_rst ),
    .rx_np_ok       ( rx_np_ok_tlp ),
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
    .tx_error       ( tx_error ),
    .bus_number     ( bus_number ),
    .dev_number     ( dev_number ),
    .func_number    ( func_number )
);


endmodule

