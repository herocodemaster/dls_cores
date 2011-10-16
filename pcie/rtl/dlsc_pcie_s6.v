
module dlsc_pcie_s6 #(
    // ** Clock relationships **
    // Specify which clock domain each component is on; components in different
    // domains may be clocked by different asynchronous clocks. Components in
    // the same domain must be clocked by the same clock. Domain 0 is assumed
    // to be the PCIe clock domain (user_clk_out).
    parameter APB_CLK_DOMAIN    = 0,
    parameter IB_CLK_DOMAIN     = 0,
    parameter OB_CLK_DOMAIN     = 0,

    // ** APB **
    parameter APB_EN            = 1,                // enable APB registers and interrupts
    parameter APB_ADDR          = 32,               // width of APB address bus
    parameter AUTO_POWEROFF     = 1,                // automatically acknowledge power-off requests
    parameter INTERRUPTS        = 1,                // number of interrupt request inputs (1-32)
    parameter INT_ASYNC         = 1,                // re-synchronize interrupt inputs

    // ** Inbound **
    // AXI
    parameter IB_ADDR           = 32,               // width of AXI address bus
    parameter IB_LEN            = 4,                // width of AXI length field
    // Write
    parameter IB_WRITE_EN       = 1,                // enable inbound write path
    parameter IB_WRITE_BUFFER   = 32,
    parameter IB_WRITE_MOT      = 16,               // max outstanding write transactions
    // Read
    parameter IB_READ_EN        = 1,                // enable inbound read path
    parameter IB_READ_BUFFER    = 256,
    parameter IB_READ_MOT       = 16,               // max outstanding read transactions
    // Address translation
    parameter [IB_ADDR-1:0] IB_TRANS_BAR0_MASK = {IB_ADDR{1'b1}},
    parameter [IB_ADDR-1:0] IB_TRANS_BAR0_BASE = {IB_ADDR{1'b0}},
    parameter [IB_ADDR-1:0] IB_TRANS_BAR1_MASK = {IB_ADDR{1'b1}},
    parameter [IB_ADDR-1:0] IB_TRANS_BAR1_BASE = {IB_ADDR{1'b0}},
    parameter [IB_ADDR-1:0] IB_TRANS_BAR2_MASK = {IB_ADDR{1'b1}},
    parameter [IB_ADDR-1:0] IB_TRANS_BAR2_BASE = {IB_ADDR{1'b0}},
    parameter [IB_ADDR-1:0] IB_TRANS_BAR3_MASK = {IB_ADDR{1'b1}},
    parameter [IB_ADDR-1:0] IB_TRANS_BAR3_BASE = {IB_ADDR{1'b0}},
    parameter [IB_ADDR-1:0] IB_TRANS_BAR4_MASK = {IB_ADDR{1'b1}},
    parameter [IB_ADDR-1:0] IB_TRANS_BAR4_BASE = {IB_ADDR{1'b0}},
    parameter [IB_ADDR-1:0] IB_TRANS_BAR5_MASK = {IB_ADDR{1'b1}},
    parameter [IB_ADDR-1:0] IB_TRANS_BAR5_BASE = {IB_ADDR{1'b0}},
    parameter [IB_ADDR-1:0] IB_TRANS_ROM_MASK  = {IB_ADDR{1'b1}},
    parameter [IB_ADDR-1:0] IB_TRANS_ROM_BASE  = {IB_ADDR{1'b0}},
    parameter [IB_ADDR-1:0] IB_TRANS_CFG_MASK  = {IB_ADDR{1'b1}},
    parameter [IB_ADDR-1:0] IB_TRANS_CFG_BASE  = {IB_ADDR{1'b0}},

    // ** Outbound **
    // AXI
    parameter OB_ADDR           = 32,               // width of AXI address bus
    parameter OB_LEN            = 4,                // width of AXI length field
    // Write
    parameter OB_WRITE_EN       = 1,                // enable outbound write path
    parameter OB_WRITE_SIZE     = 128,              // max write size (in bytes; power of 2)
    parameter OB_WRITE_MOT      = 16,               // max outstanding write transactions
    // Read
    parameter OB_READ_EN        = 1,                // enable outbound read path
    parameter OB_READ_MOT       = 16,               // max outstanding read transactions
    parameter OB_READ_CPLH      = 8,                // max receive buffer completion header space
    parameter OB_READ_CPLD      = 64,               // max receive buffer completion data space    
    parameter OB_READ_SIZE      = (OB_READ_CPLD*16),// size of read buffer (in bytes; power of 2)
    parameter OB_READ_TIMEOUT   = 625000,           // read completion timeout (default is 10ms at 62.5 MHz)
    // Misc
    parameter OB_TAG            = 5,                // PCIe tag bits
    // Address translation
    parameter OB_TRANS_REGIONS  = 0,                // number of enabled output regions (0-8; 0 disables translation)
    parameter [OB_ADDR-1:0] OB_TRANS_0_MASK = {OB_ADDR{1'b1}},
    parameter [OB_ADDR-1:0] OB_TRANS_0_BASE = {OB_ADDR{1'b0}},
    parameter [OB_ADDR-1:0] OB_TRANS_1_MASK = {OB_ADDR{1'b1}},
    parameter [OB_ADDR-1:0] OB_TRANS_1_BASE = {OB_ADDR{1'b0}},
    parameter [OB_ADDR-1:0] OB_TRANS_2_MASK = {OB_ADDR{1'b1}},
    parameter [OB_ADDR-1:0] OB_TRANS_2_BASE = {OB_ADDR{1'b0}},
    parameter [OB_ADDR-1:0] OB_TRANS_3_MASK = {OB_ADDR{1'b1}},
    parameter [OB_ADDR-1:0] OB_TRANS_3_BASE = {OB_ADDR{1'b0}},
    parameter [OB_ADDR-1:0] OB_TRANS_4_MASK = {OB_ADDR{1'b1}},
    parameter [OB_ADDR-1:0] OB_TRANS_4_BASE = {OB_ADDR{1'b0}},
    parameter [OB_ADDR-1:0] OB_TRANS_5_MASK = {OB_ADDR{1'b1}},
    parameter [OB_ADDR-1:0] OB_TRANS_5_BASE = {OB_ADDR{1'b0}},
    parameter [OB_ADDR-1:0] OB_TRANS_6_MASK = {OB_ADDR{1'b1}},
    parameter [OB_ADDR-1:0] OB_TRANS_6_BASE = {OB_ADDR{1'b0}},
    parameter [OB_ADDR-1:0] OB_TRANS_7_MASK = {OB_ADDR{1'b1}},
    parameter [OB_ADDR-1:0] OB_TRANS_7_BASE = {OB_ADDR{1'b0}}
) (
    // ** APB **
    
    // System
    input   wire                    apb_clk,
    input   wire                    apb_rst,

    // APB
    input   wire    [APB_ADDR-1:0]  apb_addr,
    input   wire                    apb_sel,
    input   wire                    apb_enable,
    input   wire                    apb_write,
    input   wire    [31:0]          apb_wdata,
    input   wire    [3:0]           apb_strb,
    output  wire                    apb_ready,
    output  wire    [31:0]          apb_rdata,
    output  wire                    apb_slverr,

    // Interrupts
    input   wire    [INTERRUPTS-1:0] apb_int_in,
    output  wire                    apb_int_out,

    // ** Inbound **
    // (AXI master, which generates requests from PCIe)
    
    // System
    input   wire                    ib_clk,
    input   wire                    ib_rst,
    
    // AXI read command
    input   wire                    ib_ar_ready,
    output  wire                    ib_ar_valid,
    output  wire    [IB_ADDR-1:0]   ib_ar_addr,
    output  wire    [IB_LEN-1:0]    ib_ar_len,

    // AXI read response
    output  wire                    ib_r_ready,
    input   wire                    ib_r_valid,
    input   wire                    ib_r_last,
    input   wire    [31:0]          ib_r_data,
    input   wire    [1:0]           ib_r_resp,

    // AXI write command
    input   wire                    ib_aw_ready,
    output  wire                    ib_aw_valid,
    output  wire    [IB_ADDR-1:0]   ib_aw_addr,
    output  wire    [IB_LEN-1:0]    ib_aw_len,

    // AXI write data
    input   wire                    ib_w_ready,
    output  wire                    ib_w_valid,
    output  wire                    ib_w_last,
    output  wire    [31:0]          ib_w_data,
    output  wire    [3:0]           ib_w_strb,

    // AXI write response
    output  wire                    ib_b_ready,
    input   wire                    ib_b_valid,
    input   wire    [1:0]           ib_b_resp,
    
    // ** Outbound **
    // (AXI slave, which sends request to PCIe)
    
    // System
    input   wire                    ob_clk,
    input   wire                    ob_rst,

    // Read Command
    output  wire                    ob_ar_ready,
    input   wire                    ob_ar_valid,
    input   wire    [OB_ADDR-1:0]   ob_ar_addr,
    input   wire    [OB_LEN-1:0]    ob_ar_len,

    // Read response
    input   wire                    ob_r_ready,
    output  wire                    ob_r_valid,
    output  wire                    ob_r_last,
    output  wire    [31:0]          ob_r_data,
    output  wire    [1:0]           ob_r_resp,
    
    // Write Command
    output  wire                    ob_aw_ready,
    input   wire                    ob_aw_valid,
    input   wire    [OB_ADDR-1:0]   ob_aw_addr,
    input   wire    [OB_LEN-1:0]    ob_aw_len,

    // Write Data
    output  wire                    ob_w_ready,
    input   wire                    ob_w_valid,
    input   wire                    ob_w_last,
    input   wire    [3:0]           ob_w_strb,
    input   wire    [31:0]          ob_w_data,

    // Write Response
    input   wire                    ob_b_ready,
    output  wire                    ob_b_valid,
    output  wire    [1:0]           ob_b_resp,

    // ** PCIe **
    // (connect directly to Spartan-6 integrated PCIe endpoint)
    
    // System Interface
    input   wire                    received_hot_reset,
    
    // Common Interface
    input   wire                    user_clk_out,
    input   wire                    user_reset_out,
    input   wire                    user_lnk_up,
    output  wire    [2:0]           fc_sel,
    input   wire    [7:0]           fc_ph,
    input   wire    [11:0]          fc_pd,
    input   wire    [7:0]           fc_nph,
    input   wire    [11:0]          fc_npd,
    input   wire    [7:0]           fc_cplh,
    input   wire    [11:0]          fc_cpld,

    // Transmit Interface
    input   wire                    s_axis_tx_tready,
    output  wire                    s_axis_tx_tvalid,
    output  wire                    s_axis_tx_tlast,
    output  wire    [31:0]          s_axis_tx_tdata,
    output  wire    [3:0]           s_axis_tx_tuser,
    input   wire    [5:0]           tx_buf_av,
    input   wire                    tx_err_drop,
    input   wire                    tx_cfg_req,
    output  wire                    tx_cfg_gnt,

    // Receive Interface
    output  wire                    rx_np_ok,
    output  wire                    m_axis_rx_tready,
    input   wire                    m_axis_rx_tvalid,
    input   wire                    m_axis_rx_tlast,
    input   wire    [31:0]          m_axis_rx_tdata,
    input   wire    [9:0]           m_axis_rx_tuser,

    // Configuration space read
    output  wire                    cfg_rd_en,
    output  wire    [9:0]           cfg_dwaddr,
    input   wire                    cfg_rd_wr_done,
    input   wire    [31:0]          cfg_do,

    // Configuration space values
    input   wire    [7:0]           cfg_bus_number,
    input   wire    [4:0]           cfg_device_number,
    input   wire    [2:0]           cfg_function_number,
    input   wire    [15:0]          cfg_status,
    input   wire    [15:0]          cfg_command,
    input   wire    [15:0]          cfg_dstatus,
    input   wire    [15:0]          cfg_dcommand,
    input   wire    [15:0]          cfg_lstatus,
    input   wire    [15:0]          cfg_lcommand,

    // Power management
    input   wire    [2:0]           cfg_pcie_link_state,
    input   wire                    cfg_to_turnoff,
    output  wire                    cfg_turnoff_ok,
    output  wire                    cfg_pm_wake,

    // Misc
    output  wire                    cfg_trn_pending,
    output  wire    [63:0]          cfg_dsn,
    
    // Interrupts
    input   wire                    cfg_interrupt_msienable,
    input   wire    [2:0]           cfg_interrupt_mmenable,
    input   wire                    cfg_interrupt_rdy,
    output  wire                    cfg_interrupt,
    output  wire                    cfg_interrupt_assert,
    output  wire    [7:0]           cfg_interrupt_di,

    // Error Reporting Signals
    input   wire                    cfg_err_cpl_rdy,
    output  wire    [47:0]          cfg_err_tlp_cpl_header,
    output  wire                    cfg_err_posted,
    output  wire                    cfg_err_locked,
    output  wire                    cfg_err_cor,
    output  wire                    cfg_err_cpl_abort,
    output  wire                    cfg_err_cpl_timeout,
    output  wire                    cfg_err_ecrc,
    output  wire                    cfg_err_ur
);


// ** Registers ** (TODO)

assign      apb_ready               = apb_sel && apb_enable;
assign      apb_rdata               = 32'd0;
assign      apb_slverr              = 1'b0;

assign      apb_int_out             = 1'b0;

// tie-off (TODO)
assign      cfg_rd_en               = 1'b0;
assign      cfg_dwaddr              = 10'd0;
assign      cfg_turnoff_ok          = cfg_to_turnoff;
assign      cfg_pm_wake             = 1'b0;
assign      cfg_dsn                 = {64{1'b0}};
assign      cfg_interrupt           = 1'b0;
assign      cfg_interrupt_assert    = 1'b0;
assign      cfg_interrupt_di        = 8'd0;


// ** Inbound **
    
wire        ib_rx_ready;
wire        ib_rx_valid;
wire [31:0] ib_rx_data;
wire        ib_rx_last;
wire        ib_rx_err;
wire [6:0]  ib_rx_bar;
wire        ib_tx_ready;
wire        ib_tx_valid;
wire [31:0] ib_tx_data;
wire        ib_tx_last;
wire        ib_tx_error;
wire        ib_err_ready;
wire        ib_err_valid;
wire        ib_err_unsupported;

dlsc_pcie_s6_inbound #(
    .ASYNC                  ( IB_CLK_DOMAIN != 0 ),
    .ADDR                   ( IB_ADDR ),
    .LEN                    ( IB_LEN ),
    .WRITE_EN               ( IB_WRITE_EN ),
    .WRITE_BUFFER           ( IB_WRITE_BUFFER ),
    .WRITE_MOT              ( IB_WRITE_MOT ),
    .READ_EN                ( IB_READ_EN ),
    .READ_BUFFER            ( IB_READ_BUFFER ),
    .READ_MOT               ( IB_READ_MOT ),
    .TRANS_BAR0_MASK        ( IB_TRANS_BAR0_MASK ),
    .TRANS_BAR0_BASE        ( IB_TRANS_BAR0_BASE ),
    .TRANS_BAR1_MASK        ( IB_TRANS_BAR1_MASK ),
    .TRANS_BAR1_BASE        ( IB_TRANS_BAR1_BASE ),
    .TRANS_BAR2_MASK        ( IB_TRANS_BAR2_MASK ),
    .TRANS_BAR2_BASE        ( IB_TRANS_BAR2_BASE ),
    .TRANS_BAR3_MASK        ( IB_TRANS_BAR3_MASK ),
    .TRANS_BAR3_BASE        ( IB_TRANS_BAR3_BASE ),
    .TRANS_BAR4_MASK        ( IB_TRANS_BAR4_MASK ),
    .TRANS_BAR4_BASE        ( IB_TRANS_BAR4_BASE ),
    .TRANS_BAR5_MASK        ( IB_TRANS_BAR5_MASK ),
    .TRANS_BAR5_BASE        ( IB_TRANS_BAR5_BASE ),
    .TRANS_ROM_MASK         ( IB_TRANS_ROM_MASK ),
    .TRANS_ROM_BASE         ( IB_TRANS_ROM_BASE ),
    .TRANS_CFG_MASK         ( IB_TRANS_CFG_MASK ),
    .TRANS_CFG_BASE         ( IB_TRANS_CFG_BASE )
) dlsc_pcie_s6_inbound_inst (
    .axi_clk                ( ib_clk ),
    .axi_rst                ( ib_rst ),
    .axi_ar_ready           ( ib_ar_ready ),
    .axi_ar_valid           ( ib_ar_valid ),
    .axi_ar_addr            ( ib_ar_addr ),
    .axi_ar_len             ( ib_ar_len ),
    .axi_r_ready            ( ib_r_ready ),
    .axi_r_valid            ( ib_r_valid ),
    .axi_r_last             ( ib_r_last ),
    .axi_r_data             ( ib_r_data ),
    .axi_r_resp             ( ib_r_resp ),
    .axi_aw_ready           ( ib_aw_ready ),
    .axi_aw_valid           ( ib_aw_valid ),
    .axi_aw_addr            ( ib_aw_addr ),
    .axi_aw_len             ( ib_aw_len ),
    .axi_w_ready            ( ib_w_ready ),
    .axi_w_valid            ( ib_w_valid ),
    .axi_w_last             ( ib_w_last ),
    .axi_w_data             ( ib_w_data ),
    .axi_w_strb             ( ib_w_strb ),
    .axi_b_ready            ( ib_b_ready ),
    .axi_b_valid            ( ib_b_valid ),
    .axi_b_resp             ( ib_b_resp ),
    .axi_rd_disable         ( 1'b0 ),   // TODO
    .axi_wr_disable         ( 1'b0 ),   // TODO
    .axi_rd_busy            (  ),       // TODO
    .axi_wr_busy            (  ),       // TODO
    .pcie_clk               ( user_clk_out ),
    .pcie_rst               ( user_reset_out ),
    .pcie_rx_np_ok          ( rx_np_ok ),
    .pcie_max_payload_size  ( cfg_dcommand[7:5] ),
    .pcie_bus_number        ( cfg_bus_number ),
    .pcie_dev_number        ( cfg_device_number ),
    .pcie_func_number       ( cfg_function_number ),
    .pcie_rx_ready          ( ib_rx_ready ),
    .pcie_rx_valid          ( ib_rx_valid ),
    .pcie_rx_data           ( ib_rx_data ),
    .pcie_rx_last           ( ib_rx_last ),
    .pcie_rx_err            ( ib_rx_err ),
    .pcie_rx_bar            ( ib_rx_bar ),
    .pcie_tx_ready          ( ib_tx_ready ),
    .pcie_tx_valid          ( ib_tx_valid ),
    .pcie_tx_data           ( ib_tx_data ),
    .pcie_tx_last           ( ib_tx_last ),
    .pcie_tx_error          ( ib_tx_error ),
    .pcie_err_ready         ( ib_err_ready ),
    .pcie_err_valid         ( ib_err_valid ),
    .pcie_err_unsupported   ( ib_err_unsupported )
);


// ** Outbound **

wire        ob_rx_ready;
wire        ob_rx_valid;
wire [31:0] ob_rx_data;
wire        ob_rx_last;
wire        ob_rx_err;
wire        ob_tx_ready;
wire        ob_tx_valid;
wire [31:0] ob_tx_data;
wire        ob_tx_last;
wire        ob_tx_error;
wire        ob_err_ready;
wire        ob_err_valid;
wire        ob_err_unexpected;
wire        ob_err_timeout;

dlsc_pcie_s6_outbound #(
    .APB_ASYNC              ( APB_CLK_DOMAIN != 0 ),
    .APB_EN                 ( APB_EN ),
    .APB_ADDR               ( APB_ADDR ),
    .ASYNC                  ( OB_CLK_DOMAIN != 0 ),
    .ADDR                   ( OB_ADDR ),
    .LEN                    ( OB_LEN ),
    .WRITE_EN               ( OB_WRITE_EN ),
    .WRITE_SIZE             ( OB_WRITE_SIZE ),
    .WRITE_MOT              ( OB_WRITE_MOT ),
    .READ_EN                ( OB_READ_EN ),
    .READ_MOT               ( OB_READ_MOT ),
    .READ_CPLH              ( OB_READ_CPLH ),
    .READ_CPLD              ( OB_READ_CPLD ),
    .READ_SIZE              ( OB_READ_SIZE ),
    .READ_TIMEOUT           ( OB_READ_TIMEOUT ),
    .TAG                    ( OB_TAG ),
    .FCHB                   ( 8 ),
    .FCDB                   ( 12 ),
    .TRANS_REGIONS          ( OB_TRANS_REGIONS ),
    .TRANS_0_MASK           ( OB_TRANS_0_MASK ),
    .TRANS_0_BASE           ( OB_TRANS_0_BASE ),
    .TRANS_1_MASK           ( OB_TRANS_1_MASK ),
    .TRANS_1_BASE           ( OB_TRANS_1_BASE ),
    .TRANS_2_MASK           ( OB_TRANS_2_MASK ),
    .TRANS_2_BASE           ( OB_TRANS_2_BASE ),
    .TRANS_3_MASK           ( OB_TRANS_3_MASK ),
    .TRANS_3_BASE           ( OB_TRANS_3_BASE ),
    .TRANS_4_MASK           ( OB_TRANS_4_MASK ),
    .TRANS_4_BASE           ( OB_TRANS_4_BASE ),
    .TRANS_5_MASK           ( OB_TRANS_5_MASK ),
    .TRANS_5_BASE           ( OB_TRANS_5_BASE ),
    .TRANS_6_MASK           ( OB_TRANS_6_MASK ),
    .TRANS_6_BASE           ( OB_TRANS_6_BASE ),
    .TRANS_7_MASK           ( OB_TRANS_7_MASK ),
    .TRANS_7_BASE           ( OB_TRANS_7_BASE )
) dlsc_pcie_s6_outbound_inst (
    .apb_clk                ( apb_clk ),
    .apb_rst                ( apb_rst ),
    .apb_addr               ( {APB_ADDR{1'b0}} ),
    .apb_sel                ( 1'b0 ),
    .apb_enable             ( 1'b0 ),
    .apb_write              ( 1'b0 ),
    .apb_wdata              ( 32'd0 ),
    .apb_strb               ( 4'd0 ),
    .apb_ready              (  ),
    .apb_rdata              (  ),
    .apb_slverr             (  ),
    .apb_ob_rd_disable      ( 1'b0 ),
    .apb_ob_wr_disable      ( 1'b0 ),
    .apb_ob_rd_busy         (  ),
    .apb_ob_wr_busy         (  ),
    .axi_clk                ( ob_clk ),
    .axi_rst                ( ob_rst ),
    .axi_ar_ready           ( ob_ar_ready ),
    .axi_ar_valid           ( ob_ar_valid ),
    .axi_ar_addr            ( ob_ar_addr ),
    .axi_ar_len             ( ob_ar_len ),
    .axi_r_ready            ( ob_r_ready ),
    .axi_r_valid            ( ob_r_valid ),
    .axi_r_last             ( ob_r_last ),
    .axi_r_data             ( ob_r_data ),
    .axi_r_resp             ( ob_r_resp ),
    .axi_aw_ready           ( ob_aw_ready ),
    .axi_aw_valid           ( ob_aw_valid ),
    .axi_aw_addr            ( ob_aw_addr ),
    .axi_aw_len             ( ob_aw_len ),
    .axi_w_ready            ( ob_w_ready ),
    .axi_w_valid            ( ob_w_valid ),
    .axi_w_last             ( ob_w_last ),
    .axi_w_strb             ( ob_w_strb ),
    .axi_w_data             ( ob_w_data ),
    .axi_b_ready            ( ob_b_ready ),
    .axi_b_valid            ( ob_b_valid ),
    .axi_b_resp             ( ob_b_resp ),
    .pcie_clk               ( user_clk_out ),
    .pcie_rst               ( user_reset_out ),
    .pcie_tlp_pending       ( cfg_trn_pending ),
    .pcie_max_payload_size  ( cfg_dcommand[7:5] ),
    .pcie_max_read_request  ( cfg_dcommand[14:12] ),
    .pcie_rcb               ( cfg_lcommand[3] ),
    .pcie_dma_en            ( cfg_command[2] ),
    .pcie_bus_number        ( cfg_bus_number ),
    .pcie_dev_number        ( cfg_device_number ),
    .pcie_func_number       ( cfg_function_number ),
    .pcie_fc_sel            ( fc_sel ),
    .pcie_fc_ph             ( fc_ph ),
    .pcie_fc_pd             ( fc_pd ),
    .pcie_rx_ready          ( ob_rx_ready ),
    .pcie_rx_valid          ( ob_rx_valid ),
    .pcie_rx_data           ( ob_rx_data ),
    .pcie_rx_last           ( ob_rx_last ),
    .pcie_rx_err            ( ob_rx_err ),
    .pcie_tx_ready          ( ob_tx_ready ),
    .pcie_tx_valid          ( ob_tx_valid ),
    .pcie_tx_data           ( ob_tx_data ),
    .pcie_tx_last           ( ob_tx_last ),
    .pcie_err_ready         ( ob_err_ready ),
    .pcie_err_valid         ( ob_err_valid ),
    .pcie_err_unexpected    ( ob_err_unexpected ),
    .pcie_err_timeout       ( ob_err_timeout )
);


// ** Receive **

wire        rx_err_ready;
wire        rx_err_valid;
wire [47:0] rx_err_header;
wire        rx_err_posted;
wire        rx_err_locked;
wire        rx_err_unsupported;
wire        rx_err_unexpected;
wire        rx_err_malformed;

dlsc_pcie_s6_rx #(
    .IB_READ_EN             ( IB_READ_EN ),
    .IB_WRITE_EN            ( IB_WRITE_EN ),
    .OB_READ_EN             ( OB_READ_EN ),
    .OB_WRITE_EN            ( OB_WRITE_EN )
) dlsc_pcie_s6_rx_inst (
    .clk                    ( user_clk_out ),
    .rst                    ( user_reset_out ),
    .pcie_rx_ready          ( m_axis_rx_tready ),
    .pcie_rx_valid          ( m_axis_rx_tvalid ),
    .pcie_rx_last           ( m_axis_rx_tlast ),
    .pcie_rx_data           ( m_axis_rx_tdata ),
    .pcie_rx_err            ( m_axis_rx_tuser[1] ),
    .pcie_rx_bar            ( m_axis_rx_tuser[8:2] ),
    .rx_err_ready           ( rx_err_ready ),
    .rx_err_valid           ( rx_err_valid ),
    .rx_err_header          ( rx_err_header ),
    .rx_err_posted          ( rx_err_posted ),
    .rx_err_locked          ( rx_err_locked ),
    .rx_err_unsupported     ( rx_err_unsupported ),
    .rx_err_unexpected      ( rx_err_unexpected ),
    .rx_err_malformed       ( rx_err_malformed ),
    .ib_rx_ready            ( ib_rx_ready ),
    .ib_rx_valid            ( ib_rx_valid ),
    .ib_rx_last             ( ib_rx_last ),
    .ib_rx_data             ( ib_rx_data ),
    .ib_rx_err              ( ib_rx_err ),
    .ib_rx_bar              ( ib_rx_bar ),
    .ob_rx_ready            ( ob_rx_ready ),
    .ob_rx_valid            ( ob_rx_valid ),
    .ob_rx_last             ( ob_rx_last ),
    .ob_rx_data             ( ob_rx_data ),
    .ob_rx_err              ( ob_rx_err )
);


// ** Transmit **

assign      s_axis_tx_tuser[0]      = 1'b0;

dlsc_pcie_s6_tx dlsc_pcie_s6_tx_inst (
    .clk                    ( user_clk_out ),
    .rst                    ( user_reset_out ),
    .pcie_tx_ready          ( s_axis_tx_tready ),
    .pcie_tx_valid          ( s_axis_tx_tvalid ),
    .pcie_tx_last           ( s_axis_tx_tlast ),
    .pcie_tx_data           ( s_axis_tx_tdata ),
    .pcie_tx_dsc            ( s_axis_tx_tuser[3] ),
    .pcie_tx_stream         ( s_axis_tx_tuser[2] ),
    .pcie_tx_err_fwd        ( s_axis_tx_tuser[1] ),
    .pcie_tx_buf_av         ( tx_buf_av ),
    .pcie_tx_drop           ( tx_err_drop ),
    .pcie_tx_cfg_req        ( tx_cfg_req ),
    .pcie_tx_cfg_gnt        ( tx_cfg_gnt ),
    .pcie_err_ready         ( cfg_err_cpl_rdy ),
    .pcie_err_header        ( cfg_err_tlp_cpl_header ),
    .pcie_err_posted        ( cfg_err_posted ),
    .pcie_err_locked        ( cfg_err_locked ),
    .pcie_err_cor           ( cfg_err_cor ),
    .pcie_err_abort         ( cfg_err_cpl_abort ),
    .pcie_err_timeout       ( cfg_err_cpl_timeout ),
    .pcie_err_ecrc          ( cfg_err_ecrc ),
    .pcie_err_unsupported   ( cfg_err_ur ),
    .rx_err_ready           ( rx_err_ready ),
    .rx_err_valid           ( rx_err_valid ),
    .rx_err_header          ( rx_err_header ),
    .rx_err_posted          ( rx_err_posted ),
    .rx_err_locked          ( rx_err_locked ),
    .rx_err_unsupported     ( rx_err_unsupported ),
    .rx_err_unexpected      ( rx_err_unexpected ),
    .rx_err_malformed       ( rx_err_malformed ),
    .ib_tx_ready            ( ib_tx_ready ),
    .ib_tx_valid            ( ib_tx_valid ),
    .ib_tx_last             ( ib_tx_last ),
    .ib_tx_error            ( ib_tx_error ),
    .ib_tx_data             ( ib_tx_data ),
    .ib_err_ready           ( ib_err_ready ),
    .ib_err_valid           ( ib_err_valid ),
    .ib_err_unsupported     ( ib_err_unsupported ),
    .ob_tx_ready            ( ob_tx_ready ),
    .ob_tx_valid            ( ob_tx_valid ),
    .ob_tx_last             ( ob_tx_last ),
    .ob_tx_data             ( ob_tx_data ),
    .ob_err_ready           ( ob_err_ready ),
    .ob_err_valid           ( ob_err_valid ),
    .ob_err_unexpected      ( ob_err_unexpected ),
    .ob_err_timeout         ( ob_err_timeout )
);


endmodule

