
module dlsc_sp605_core #(
    parameter MIG_ID            = 4,
    parameter MIG_ADDR          = 32,
    parameter MIG_LEN           = 8,
    parameter OB_READ_CPLH      = 40,
    parameter OB_READ_CPLD      = 467,
    parameter BYTE_SWAP         = 0,        // set for x86 hosts
    parameter LOCAL_DMA_DESC    = 1,        // fetch DMA commands from MIG (otherwise fetch over PCIe)
    parameter BUFFER            = 0         // enable buffering in AXI routers
) (
    // ** System **
    input   wire                    clk,
    input   wire                    rst,

    // ** MIG **
    // Common
    // Port 0
    output  wire                    c3_s0_axi_aclk,
    output  wire                    c3_s0_axi_aresetn,
    output  wire    [MIG_ID-1:0]    c3_s0_axi_awid,
    output  wire    [MIG_ADDR-1:0]  c3_s0_axi_awaddr,
    output  wire    [7:0]           c3_s0_axi_awlen,
    output  wire    [2:0]           c3_s0_axi_awsize,
    output  wire    [1:0]           c3_s0_axi_awburst,
    output  wire    [0:0]           c3_s0_axi_awlock,
    output  wire    [3:0]           c3_s0_axi_awcache,
    output  wire    [2:0]           c3_s0_axi_awprot,
    output  wire    [3:0]           c3_s0_axi_awqos,
    output  wire                    c3_s0_axi_awvalid,
    input   wire                    c3_s0_axi_awready,
    output  wire    [31:0]          c3_s0_axi_wdata,
    output  wire    [3:0]           c3_s0_axi_wstrb,
    output  wire                    c3_s0_axi_wlast,
    output  wire                    c3_s0_axi_wvalid,
    input   wire                    c3_s0_axi_wready,
    input   wire    [MIG_ID-1:0]    c3_s0_axi_bid,
    input   wire    [1:0]           c3_s0_axi_bresp,
    input   wire                    c3_s0_axi_bvalid,
    output  wire                    c3_s0_axi_bready,
    output  wire    [MIG_ID-1:0]    c3_s0_axi_arid,
    output  wire    [MIG_ADDR-1:0]  c3_s0_axi_araddr,
    output  wire    [7:0]           c3_s0_axi_arlen,
    output  wire    [2:0]           c3_s0_axi_arsize,
    output  wire    [1:0]           c3_s0_axi_arburst,
    output  wire    [0:0]           c3_s0_axi_arlock,
    output  wire    [3:0]           c3_s0_axi_arcache,
    output  wire    [2:0]           c3_s0_axi_arprot,
    output  wire    [3:0]           c3_s0_axi_arqos,
    output  wire                    c3_s0_axi_arvalid,
    input   wire                    c3_s0_axi_arready,
    input   wire    [MIG_ID-1:0]    c3_s0_axi_rid,
    input   wire    [31:0]          c3_s0_axi_rdata,
    input   wire    [1:0]           c3_s0_axi_rresp,
    input   wire                    c3_s0_axi_rlast,
    input   wire                    c3_s0_axi_rvalid,
    output  wire                    c3_s0_axi_rready,
    // Port 1
    output  wire                    c3_s1_axi_aclk,
    output  wire                    c3_s1_axi_aresetn,
    output  wire    [MIG_ID-1:0]    c3_s1_axi_awid,
    output  wire    [MIG_ADDR-1:0]  c3_s1_axi_awaddr,
    output  wire    [7:0]           c3_s1_axi_awlen,
    output  wire    [2:0]           c3_s1_axi_awsize,
    output  wire    [1:0]           c3_s1_axi_awburst,
    output  wire    [0:0]           c3_s1_axi_awlock,
    output  wire    [3:0]           c3_s1_axi_awcache,
    output  wire    [2:0]           c3_s1_axi_awprot,
    output  wire    [3:0]           c3_s1_axi_awqos,
    output  wire                    c3_s1_axi_awvalid,
    input   wire                    c3_s1_axi_awready,
    output  wire    [31:0]          c3_s1_axi_wdata,
    output  wire    [3:0]           c3_s1_axi_wstrb,
    output  wire                    c3_s1_axi_wlast,
    output  wire                    c3_s1_axi_wvalid,
    input   wire                    c3_s1_axi_wready,
    input   wire    [MIG_ID-1:0]    c3_s1_axi_bid,
    input   wire    [1:0]           c3_s1_axi_bresp,
    input   wire                    c3_s1_axi_bvalid,
    output  wire                    c3_s1_axi_bready,
    output  wire    [MIG_ID-1:0]    c3_s1_axi_arid,
    output  wire    [MIG_ADDR-1:0]  c3_s1_axi_araddr,
    output  wire    [7:0]           c3_s1_axi_arlen,
    output  wire    [2:0]           c3_s1_axi_arsize,
    output  wire    [1:0]           c3_s1_axi_arburst,
    output  wire    [0:0]           c3_s1_axi_arlock,
    output  wire    [3:0]           c3_s1_axi_arcache,
    output  wire    [2:0]           c3_s1_axi_arprot,
    output  wire    [3:0]           c3_s1_axi_arqos,
    output  wire                    c3_s1_axi_arvalid,
    input   wire                    c3_s1_axi_arready,
    input   wire    [MIG_ID-1:0]    c3_s1_axi_rid,
    input   wire    [31:0]          c3_s1_axi_rdata,
    input   wire    [1:0]           c3_s1_axi_rresp,
    input   wire                    c3_s1_axi_rlast,
    input   wire                    c3_s1_axi_rvalid,
    output  wire                    c3_s1_axi_rready,
    // Port 3
    output  wire                    c3_s2_axi_aclk,
    output  wire                    c3_s2_axi_aresetn,
    output  wire    [MIG_ID-1:0]    c3_s2_axi_awid,
    output  wire    [MIG_ADDR-1:0]  c3_s2_axi_awaddr,
    output  wire    [7:0]           c3_s2_axi_awlen,
    output  wire    [2:0]           c3_s2_axi_awsize,
    output  wire    [1:0]           c3_s2_axi_awburst,
    output  wire    [0:0]           c3_s2_axi_awlock,
    output  wire    [3:0]           c3_s2_axi_awcache,
    output  wire    [2:0]           c3_s2_axi_awprot,
    output  wire    [3:0]           c3_s2_axi_awqos,
    output  wire                    c3_s2_axi_awvalid,
    input   wire                    c3_s2_axi_awready,
    output  wire    [31:0]          c3_s2_axi_wdata,
    output  wire    [3:0]           c3_s2_axi_wstrb,
    output  wire                    c3_s2_axi_wlast,
    output  wire                    c3_s2_axi_wvalid,
    input   wire                    c3_s2_axi_wready,
    input   wire    [MIG_ID-1:0]    c3_s2_axi_bid,
    input   wire    [1:0]           c3_s2_axi_bresp,
    input   wire                    c3_s2_axi_bvalid,
    output  wire                    c3_s2_axi_bready,
    output  wire    [MIG_ID-1:0]    c3_s2_axi_arid,
    output  wire    [MIG_ADDR-1:0]  c3_s2_axi_araddr,
    output  wire    [7:0]           c3_s2_axi_arlen,
    output  wire    [2:0]           c3_s2_axi_arsize,
    output  wire    [1:0]           c3_s2_axi_arburst,
    output  wire    [0:0]           c3_s2_axi_arlock,
    output  wire    [3:0]           c3_s2_axi_arcache,
    output  wire    [2:0]           c3_s2_axi_arprot,
    output  wire    [3:0]           c3_s2_axi_arqos,
    output  wire                    c3_s2_axi_arvalid,
    input   wire                    c3_s2_axi_arready,
    input   wire    [MIG_ID-1:0]    c3_s2_axi_rid,
    input   wire    [31:0]          c3_s2_axi_rdata,
    input   wire    [1:0]           c3_s2_axi_rresp,
    input   wire                    c3_s2_axi_rlast,
    input   wire                    c3_s2_axi_rvalid,
    output  wire                    c3_s2_axi_rready,
    // Port 3
    output  wire                    c3_s3_axi_aclk,
    output  wire                    c3_s3_axi_aresetn,
    output  wire    [MIG_ID-1:0]    c3_s3_axi_awid,
    output  wire    [MIG_ADDR-1:0]  c3_s3_axi_awaddr,
    output  wire    [7:0]           c3_s3_axi_awlen,
    output  wire    [2:0]           c3_s3_axi_awsize,
    output  wire    [1:0]           c3_s3_axi_awburst,
    output  wire    [0:0]           c3_s3_axi_awlock,
    output  wire    [3:0]           c3_s3_axi_awcache,
    output  wire    [2:0]           c3_s3_axi_awprot,
    output  wire    [3:0]           c3_s3_axi_awqos,
    output  wire                    c3_s3_axi_awvalid,
    input   wire                    c3_s3_axi_awready,
    output  wire    [31:0]          c3_s3_axi_wdata,
    output  wire    [3:0]           c3_s3_axi_wstrb,
    output  wire                    c3_s3_axi_wlast,
    output  wire                    c3_s3_axi_wvalid,
    input   wire                    c3_s3_axi_wready,
    input   wire    [MIG_ID-1:0]    c3_s3_axi_bid,
    input   wire    [1:0]           c3_s3_axi_bresp,
    input   wire                    c3_s3_axi_bvalid,
    output  wire                    c3_s3_axi_bready,
    output  wire    [MIG_ID-1:0]    c3_s3_axi_arid,
    output  wire    [MIG_ADDR-1:0]  c3_s3_axi_araddr,
    output  wire    [7:0]           c3_s3_axi_arlen,
    output  wire    [2:0]           c3_s3_axi_arsize,
    output  wire    [1:0]           c3_s3_axi_arburst,
    output  wire    [0:0]           c3_s3_axi_arlock,
    output  wire    [3:0]           c3_s3_axi_arcache,
    output  wire    [2:0]           c3_s3_axi_arprot,
    output  wire    [3:0]           c3_s3_axi_arqos,
    output  wire                    c3_s3_axi_arvalid,
    input   wire                    c3_s3_axi_arready,
    input   wire    [MIG_ID-1:0]    c3_s3_axi_rid,
    input   wire    [31:0]          c3_s3_axi_rdata,
    input   wire    [1:0]           c3_s3_axi_rresp,
    input   wire                    c3_s3_axi_rlast,
    input   wire                    c3_s3_axi_rvalid,
    output  wire                    c3_s3_axi_rready,

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

localparam ADDR             = MIG_ADDR;
localparam LEN              = 4;
localparam APB_ADDR         = ADDR;
localparam INTERRUPTS       = 3;
localparam OB_ADDR          = 64;
localparam OB_LEN           = 8;

localparam CMD_ADDR         = LOCAL_DMA_DESC ? ADDR : OB_ADDR;
localparam CMD_LEN          = LOCAL_DMA_DESC ? LEN  : OB_LEN;

localparam [ADDR-1:0] APB_MASK  = 32'h000F_FFFF;    // 1 MB
localparam [ADDR-1:0] APB_BASE  = 32'h8000_0000;
localparam [ADDR-1:0] DRAM_MASK = 32'h07FF_FFFF;    // 128 MB
localparam [ADDR-1:0] DRAM_BASE = 32'h0000_0000;

wire                    apb_sel;
wire    [APB_ADDR-1:0]  apb_addr;
wire                    apb_enable;
wire                    apb_write;
wire    [31:0]          apb_wdata;
wire    [3:0]           apb_strb;


// ** PCIe **

wire                    int_pcie;

reg                     apb_sel_pcie;
wire                    apb_ready_pcie;
wire    [31:0]          apb_rdata_pcie;
wire                    apb_slverr_pcie;

wire    [INTERRUPTS-1:0] apb_int_in;
    
wire                    ib_ar_ready;
wire                    ib_ar_valid;
wire    [ADDR-1:0]      ib_ar_addr;
wire    [LEN-1:0]       ib_ar_len;
wire                    ib_r_ready;
wire                    ib_r_valid;
wire                    ib_r_last;
wire    [31:0]          ib_r_data;
wire    [1:0]           ib_r_resp;
wire                    ib_aw_ready;
wire                    ib_aw_valid;
wire    [ADDR-1:0]      ib_aw_addr;
wire    [LEN-1:0]       ib_aw_len;
wire                    ib_w_ready;
wire                    ib_w_valid;
wire                    ib_w_last;
wire    [31:0]          ib_w_data;
wire    [3:0]           ib_w_strb;
wire                    ib_b_ready;
wire                    ib_b_valid;
wire    [1:0]           ib_b_resp;

wire                    ob_ar_ready;
wire                    ob_ar_valid;
wire    [OB_ADDR-1:0]   ob_ar_addr;
wire    [OB_LEN-1:0]    ob_ar_len;
wire                    ob_r_ready;
wire                    ob_r_valid;
wire                    ob_r_last;
wire    [31:0]          ob_r_data;
wire    [1:0]           ob_r_resp;
wire                    ob_aw_ready;
wire                    ob_aw_valid;
wire    [OB_ADDR-1:0]   ob_aw_addr;
wire    [OB_LEN-1:0]    ob_aw_len;
wire                    ob_w_ready;
wire                    ob_w_valid;
wire                    ob_w_last;
wire    [3:0]           ob_w_strb;
wire    [31:0]          ob_w_data;
wire                    ob_b_ready;
wire                    ob_b_valid;
wire    [1:0]           ob_b_resp;

dlsc_pcie_s6 #(
    // ** Clock relationships **
    .APB_CLK_DOMAIN     ( 1 ),
    .IB_CLK_DOMAIN      ( 1 ),
    .OB_CLK_DOMAIN      ( 1 ),
    // ** APB **
    .APB_EN             ( 1 ),
    .APB_ADDR           ( APB_ADDR ),
    .INTERRUPTS         ( INTERRUPTS ),
    .INT_ASYNC          ( 0 ),              // all interrupts are on 'clk' domain
    // ** Inbound **
    .IB_ADDR            ( ADDR ),
    .IB_LEN             ( LEN ),
    .IB_BYTE_SWAP       ( BYTE_SWAP ),
    .IB_WRITE_EN        ( 1 ),
    .IB_WRITE_BUFFER    ( 32 ),             // 128 bytes
    .IB_WRITE_MOT       ( 16 ),
    .IB_READ_EN         ( 1 ),
    .IB_READ_BUFFER     ( 256 ),            // 1024 bytes
    .IB_READ_MOT        ( 16 ),
    .IB_TRANS_BAR0_MASK ( APB_MASK ),
    .IB_TRANS_BAR0_BASE ( APB_BASE ),
    .IB_TRANS_BAR2_MASK ( DRAM_MASK ),
    .IB_TRANS_BAR2_BASE ( DRAM_BASE ),
    // ** Outbound **
    .OB_ADDR            ( OB_ADDR ),
    .OB_LEN             ( OB_LEN ),
    .OB_BYTE_SWAP       ( BYTE_SWAP ),
    .OB_WRITE_EN        ( 1 ),
    .OB_WRITE_SIZE      ( 512 ),            // 512 bytes
    .OB_WRITE_MOT       ( 16 ),
    .OB_READ_EN         ( 1 ),
    .OB_READ_MOT        ( 16 ),
    .OB_READ_CPLH       ( OB_READ_CPLH ),
    .OB_READ_CPLD       ( OB_READ_CPLD ),
    .OB_READ_SIZE       ( 8192 ),           // 8192 bytes
    .OB_TRANS_REGIONS   ( 0 )               // no outbound translation (DMA engines will generate full 64-bit addresses)
) dlsc_pcie_s6_inst (
    // ** APB **
    .apb_clk ( clk ),
    .apb_rst ( rst ),
    .apb_addr ( apb_addr ),
    .apb_sel ( apb_sel_pcie ),
    .apb_enable ( apb_enable ),
    .apb_write ( apb_write ),
    .apb_wdata ( apb_wdata ),
    .apb_strb ( apb_strb ),
    .apb_ready ( apb_ready_pcie ),
    .apb_rdata ( apb_rdata_pcie ),
    .apb_slverr ( apb_slverr_pcie ),
    .apb_int_in ( apb_int_in ),
    .apb_int_out ( int_pcie ),
    // ** Inbound **
    .ib_clk ( clk ),
    .ib_rst ( rst ),
    .ib_ar_ready ( ib_ar_ready ),
    .ib_ar_valid ( ib_ar_valid ),
    .ib_ar_addr ( ib_ar_addr ),
    .ib_ar_len ( ib_ar_len ),
    .ib_r_ready ( ib_r_ready ),
    .ib_r_valid ( ib_r_valid ),
    .ib_r_last ( ib_r_last ),
    .ib_r_data ( ib_r_data ),
    .ib_r_resp ( ib_r_resp ),
    .ib_aw_ready ( ib_aw_ready ),
    .ib_aw_valid ( ib_aw_valid ),
    .ib_aw_addr ( ib_aw_addr ),
    .ib_aw_len ( ib_aw_len ),
    .ib_w_ready ( ib_w_ready ),
    .ib_w_valid ( ib_w_valid ),
    .ib_w_last ( ib_w_last ),
    .ib_w_data ( ib_w_data ),
    .ib_w_strb ( ib_w_strb ),
    .ib_b_ready ( ib_b_ready ),
    .ib_b_valid ( ib_b_valid ),
    .ib_b_resp ( ib_b_resp ),
    // ** Outbound **
    .ob_clk ( clk ),
    .ob_rst ( rst ),
    .ob_ar_ready ( ob_ar_ready ),
    .ob_ar_valid ( ob_ar_valid ),
    .ob_ar_addr ( ob_ar_addr ),
    .ob_ar_len ( ob_ar_len ),
    .ob_r_ready ( ob_r_ready ),
    .ob_r_valid ( ob_r_valid ),
    .ob_r_last ( ob_r_last ),
    .ob_r_data ( ob_r_data ),
    .ob_r_resp ( ob_r_resp ),
    .ob_aw_ready ( ob_aw_ready ),
    .ob_aw_valid ( ob_aw_valid ),
    .ob_aw_addr ( ob_aw_addr ),
    .ob_aw_len ( ob_aw_len ),
    .ob_w_ready ( ob_w_ready ),
    .ob_w_valid ( ob_w_valid ),
    .ob_w_last ( ob_w_last ),
    .ob_w_strb ( ob_w_strb ),
    .ob_w_data ( ob_w_data ),
    .ob_b_ready ( ob_b_ready ),
    .ob_b_valid ( ob_b_valid ),
    .ob_b_resp ( ob_b_resp ),
    // ** PCIe **
    .received_hot_reset ( received_hot_reset ),
    .user_clk_out ( user_clk_out ),
    .user_reset_out ( user_reset_out ),
    .user_lnk_up ( user_lnk_up ),
    .fc_sel ( fc_sel ),
    .fc_ph ( fc_ph ),
    .fc_pd ( fc_pd ),
    .fc_nph ( fc_nph ),
    .fc_npd ( fc_npd ),
    .fc_cplh ( fc_cplh ),
    .fc_cpld ( fc_cpld ),
    .s_axis_tx_tready ( s_axis_tx_tready ),
    .s_axis_tx_tvalid ( s_axis_tx_tvalid ),
    .s_axis_tx_tlast ( s_axis_tx_tlast ),
    .s_axis_tx_tdata ( s_axis_tx_tdata ),
    .s_axis_tx_tuser ( s_axis_tx_tuser ),
    .tx_buf_av ( tx_buf_av ),
    .tx_err_drop ( tx_err_drop ),
    .tx_cfg_req ( tx_cfg_req ),
    .tx_cfg_gnt ( tx_cfg_gnt ),
    .rx_np_ok ( rx_np_ok ),
    .m_axis_rx_tready ( m_axis_rx_tready ),
    .m_axis_rx_tvalid ( m_axis_rx_tvalid ),
    .m_axis_rx_tlast ( m_axis_rx_tlast ),
    .m_axis_rx_tdata ( m_axis_rx_tdata ),
    .m_axis_rx_tuser ( m_axis_rx_tuser ),
    .cfg_rd_en ( cfg_rd_en ),
    .cfg_dwaddr ( cfg_dwaddr ),
    .cfg_rd_wr_done ( cfg_rd_wr_done ),
    .cfg_do ( cfg_do ),
    .cfg_bus_number ( cfg_bus_number ),
    .cfg_device_number ( cfg_device_number ),
    .cfg_function_number ( cfg_function_number ),
    .cfg_status ( cfg_status ),
    .cfg_command ( cfg_command ),
    .cfg_dstatus ( cfg_dstatus ),
    .cfg_dcommand ( cfg_dcommand ),
    .cfg_lstatus ( cfg_lstatus ),
    .cfg_lcommand ( cfg_lcommand ),
    .cfg_pcie_link_state ( cfg_pcie_link_state ),
    .cfg_to_turnoff ( cfg_to_turnoff ),
    .cfg_turnoff_ok ( cfg_turnoff_ok ),
    .cfg_pm_wake ( cfg_pm_wake ),
    .cfg_trn_pending ( cfg_trn_pending ),
    .cfg_dsn ( cfg_dsn ),
    .cfg_interrupt_msienable ( cfg_interrupt_msienable ),
    .cfg_interrupt_mmenable ( cfg_interrupt_mmenable ),
    .cfg_interrupt_rdy ( cfg_interrupt_rdy ),
    .cfg_interrupt ( cfg_interrupt ),
    .cfg_interrupt_assert ( cfg_interrupt_assert ),
    .cfg_interrupt_di ( cfg_interrupt_di ),
    .cfg_err_cpl_rdy ( cfg_err_cpl_rdy ),
    .cfg_err_tlp_cpl_header ( cfg_err_tlp_cpl_header ),
    .cfg_err_posted ( cfg_err_posted ),
    .cfg_err_locked ( cfg_err_locked ),
    .cfg_err_cor ( cfg_err_cor ),
    .cfg_err_cpl_abort ( cfg_err_cpl_abort ),
    .cfg_err_cpl_timeout ( cfg_err_cpl_timeout ),
    .cfg_err_ecrc ( cfg_err_ecrc ),
    .cfg_err_ur ( cfg_err_ur )
);

// ** APB Bridge **

wire                    apb_ar_ready;
wire                    apb_ar_valid;
wire    [ADDR-1:0]      apb_ar_addr;
wire    [LEN-1:0]       apb_ar_len;
wire                    apb_r_ready;
wire                    apb_r_valid;
wire                    apb_r_last;
wire    [31:0]          apb_r_data;
wire    [1:0]           apb_r_resp;
wire                    apb_aw_ready;
wire                    apb_aw_valid;
wire    [ADDR-1:0]      apb_aw_addr;
wire    [LEN-1:0]       apb_aw_len;
wire                    apb_w_ready;
wire                    apb_w_valid;
wire                    apb_w_last;
wire    [31:0]          apb_w_data;
wire    [3:0]           apb_w_strb;
wire                    apb_b_ready;
wire                    apb_b_valid;
wire    [1:0]           apb_b_resp;

wire                    apb_ready;
wire    [31:0]          apb_rdata;
wire                    apb_slverr;

dlsc_axi_to_apb #(
    .DATA           ( 32 ),
    .ADDR           ( ADDR ),
    .LEN            ( LEN )
) dlsc_axi_to_apb_inst (
    .clk ( clk ),
    .rst ( rst ),
    // ** AXI **
    .axi_ar_ready ( apb_ar_ready ),
    .axi_ar_valid ( apb_ar_valid ),
    .axi_ar_addr ( apb_ar_addr ),
    .axi_ar_len ( apb_ar_len ),
    .axi_r_ready ( apb_r_ready ),
    .axi_r_valid ( apb_r_valid ),
    .axi_r_last ( apb_r_last ),
    .axi_r_data ( apb_r_data ),
    .axi_r_resp ( apb_r_resp ),
    .axi_aw_ready ( apb_aw_ready ),
    .axi_aw_valid ( apb_aw_valid ),
    .axi_aw_addr ( apb_aw_addr ),
    .axi_aw_len ( apb_aw_len ),
    .axi_w_ready ( apb_w_ready ),
    .axi_w_valid ( apb_w_valid ),
    .axi_w_last ( apb_w_last ),
    .axi_w_data ( apb_w_data ),
    .axi_w_strb ( apb_w_strb ),
    .axi_b_ready ( apb_b_ready ),
    .axi_b_valid ( apb_b_valid ),
    .axi_b_resp ( apb_b_resp ),
    // ** APB **
    .apb_addr ( apb_addr ),
    .apb_sel ( apb_sel ),
    .apb_enable ( apb_enable ),
    .apb_write ( apb_write ),
    .apb_wdata ( apb_wdata ),
    .apb_strb ( apb_strb ),
    .apb_ready ( apb_ready ),
    .apb_rdata ( apb_rdata ),
    .apb_slverr ( apb_slverr )
);

// ** Inbound Router **

dlsc_axi_router_rd #(
    .ADDR       ( ADDR ),
    .DATA       ( 32 ),
    .LEN        ( LEN ),
    .BUFFER     ( BUFFER ),
    .INPUTS     ( 1 ),
    .OUTPUTS    ( 2 ),
    .MASKS      ( { DRAM_MASK, APB_MASK } ),
    .BASES      ( { DRAM_BASE, APB_BASE } )
) dlsc_axi_router_rd_inbound (
    .clk ( clk ),
    .rst ( rst ),
    .in_ar_ready ( ib_ar_ready ),
    .in_ar_valid ( ib_ar_valid ),
    .in_ar_addr ( ib_ar_addr ),
    .in_ar_len ( ib_ar_len ),
    .in_r_ready ( ib_r_ready ),
    .in_r_valid ( ib_r_valid ),
    .in_r_last ( ib_r_last ),
    .in_r_data ( ib_r_data ),
    .in_r_resp ( ib_r_resp ),
    .out_ar_ready ( { c3_s0_axi_arready , apb_ar_ready } ),
    .out_ar_valid ( { c3_s0_axi_arvalid , apb_ar_valid } ),
    .out_ar_addr ( { c3_s0_axi_araddr , apb_ar_addr } ),
    .out_ar_len ( { c3_s0_axi_arlen[LEN-1:0] , apb_ar_len } ),
    .out_r_ready ( { c3_s0_axi_rready , apb_r_ready } ),
    .out_r_valid ( { c3_s0_axi_rvalid , apb_r_valid } ),
    .out_r_last ( { c3_s0_axi_rlast , apb_r_last } ),
    .out_r_data ( { c3_s0_axi_rdata , apb_r_data } ),
    .out_r_resp ( { c3_s0_axi_rresp , apb_r_resp } )
);

dlsc_axi_router_wr #(
    .ADDR       ( ADDR ),
    .DATA       ( 32 ),
    .LEN        ( LEN ),
    .BUFFER     ( BUFFER ),
    .INPUTS     ( 1 ),
    .OUTPUTS    ( 2 ),
    .MASKS      ( { DRAM_MASK, APB_MASK } ),
    .BASES      ( { DRAM_BASE, APB_BASE } )
) dlsc_axi_router_wr_inbound (
    .clk ( clk ),
    .rst ( rst ),
    .in_aw_ready ( ib_aw_ready ),
    .in_aw_valid ( ib_aw_valid ),
    .in_aw_addr ( ib_aw_addr ),
    .in_aw_len ( ib_aw_len ),
    .in_w_ready ( ib_w_ready ),
    .in_w_valid ( ib_w_valid ),
    .in_w_last ( ib_w_last ),
    .in_w_data ( ib_w_data ),
    .in_w_strb ( ib_w_strb ),
    .in_b_ready ( ib_b_ready ),
    .in_b_valid ( ib_b_valid ),
    .in_b_resp ( ib_b_resp ),
    .out_aw_ready ( { c3_s0_axi_awready , apb_aw_ready } ),
    .out_aw_valid ( { c3_s0_axi_awvalid , apb_aw_valid } ),
    .out_aw_addr ( { c3_s0_axi_awaddr , apb_aw_addr } ),
    .out_aw_len ( { c3_s0_axi_awlen[LEN-1:0] , apb_aw_len } ),
    .out_w_ready ( { c3_s0_axi_wready , apb_w_ready } ),
    .out_w_valid ( { c3_s0_axi_wvalid , apb_w_valid } ),
    .out_w_last ( { c3_s0_axi_wlast , apb_w_last } ),
    .out_w_data ( { c3_s0_axi_wdata , apb_w_data } ),
    .out_w_strb ( { c3_s0_axi_wstrb , apb_w_strb } ),
    .out_b_ready ( { c3_s0_axi_bready , apb_b_ready } ),
    .out_b_valid ( { c3_s0_axi_bvalid , apb_b_valid } ),
    .out_b_resp ( { c3_s0_axi_bresp , apb_b_resp } )
);

assign  c3_s0_axi_aclk                      = clk;
assign  c3_s0_axi_aresetn                   = !rst;
assign  c3_s0_axi_arid                      = 0;
assign  c3_s0_axi_arlen[MIG_LEN-1:LEN]      = 0;
assign  c3_s0_axi_arsize                    = 3'b010;   // 32-bits per beat
assign  c3_s0_axi_arburst                   = 2'b01;    // INCR
assign  c3_s0_axi_arlock                    = 1'b0;
assign  c3_s0_axi_arcache                   = 4'b0011;  // modifiable, bufferable
assign  c3_s0_axi_arprot                    = 3'b000;   // unprivileged, secure
assign  c3_s0_axi_arqos                     = 4'b0000;  // no QoS
assign  c3_s0_axi_awid                      = 0;
assign  c3_s0_axi_awlen[MIG_LEN-1:LEN]      = 0;
assign  c3_s0_axi_awsize                    = 3'b010;   // 32-bits per beat
assign  c3_s0_axi_awburst                   = 2'b01;    // INCR
assign  c3_s0_axi_awlock                    = 1'b0;
assign  c3_s0_axi_awcache                   = 4'b0011;  // modifiable, bufferable
assign  c3_s0_axi_awprot                    = 3'b000;   // unprivileged, secure
assign  c3_s0_axi_awqos                     = 4'b0000;  // no QoS

// ** Outbound Write DMA **

wire                    int_dmawr;

reg                     apb_sel_dmawr;
wire                    apb_ready_dmawr;
wire    [31:0]          apb_rdata_dmawr;

wire                    dmawr_cmd_ar_ready;
wire                    dmawr_cmd_ar_valid;
wire    [CMD_ADDR-1:0]  dmawr_cmd_ar_addr;
wire    [CMD_LEN-1:0]   dmawr_cmd_ar_len;
wire                    dmawr_cmd_r_ready;
wire                    dmawr_cmd_r_valid;
wire                    dmawr_cmd_r_last;
wire    [31:0]          dmawr_cmd_r_data;
wire    [1:0]           dmawr_cmd_r_resp;

dlsc_dma_core #(
    .APB_ADDR       ( APB_ADDR ),
    .CMD_ADDR       ( CMD_ADDR ),
    .CMD_LEN        ( CMD_LEN ),
    .READ_ADDR      ( MIG_ADDR ),
    .READ_LEN       ( MIG_LEN ),
    .READ_MOT       ( 16 ),
    .WRITE_ADDR     ( OB_ADDR ),
    .WRITE_LEN      ( OB_LEN ),
    .WRITE_MOT      ( 16 ),
    .DATA           ( 32 ),
    .BUFFER_SIZE    ( 512 ),
    .TRIGGERS       ( 1 )
) dlsc_dma_core_outbound_write (
    .clk ( clk ),
    .rst ( rst ),
    .int_out ( int_dmawr ),
    .trig_in ( 1'b0 ),
    .trig_in_ack (  ),
    .trig_out (  ),
    .trig_out_ack ( 1'b0 ),
    .apb_sel ( apb_sel_dmawr ),
    .apb_enable ( apb_enable ),
    .apb_write ( apb_write ),
    .apb_addr ( apb_addr ),
    .apb_wdata ( apb_wdata ),
    .apb_rdata ( apb_rdata_dmawr ),
    .apb_ready ( apb_ready_dmawr ),
    .cmd_ar_ready ( dmawr_cmd_ar_ready ),
    .cmd_ar_valid ( dmawr_cmd_ar_valid ),
    .cmd_ar_addr ( dmawr_cmd_ar_addr ),
    .cmd_ar_len ( dmawr_cmd_ar_len ),
    .cmd_r_ready ( dmawr_cmd_r_ready ),
    .cmd_r_valid ( dmawr_cmd_r_valid ),
    .cmd_r_last ( dmawr_cmd_r_last ),
    .cmd_r_data ( dmawr_cmd_r_data ),
    .cmd_r_resp ( dmawr_cmd_r_resp ),
    .rd_ar_ready ( c3_s1_axi_arready ),
    .rd_ar_valid ( c3_s1_axi_arvalid ),
    .rd_ar_addr ( c3_s1_axi_araddr ),
    .rd_ar_len ( c3_s1_axi_arlen ),
    .rd_r_ready ( c3_s1_axi_rready ),
    .rd_r_valid ( c3_s1_axi_rvalid ),
    .rd_r_last ( c3_s1_axi_rlast ),
    .rd_r_data ( c3_s1_axi_rdata ),
    .rd_r_resp ( c3_s1_axi_rresp ),
    .wr_aw_ready ( ob_aw_ready ),
    .wr_aw_valid ( ob_aw_valid ),
    .wr_aw_addr ( ob_aw_addr ),
    .wr_aw_len ( ob_aw_len ),
    .wr_w_ready ( ob_w_ready ),
    .wr_w_valid ( ob_w_valid ),
    .wr_w_last ( ob_w_last ),
    .wr_w_strb ( ob_w_strb ),
    .wr_w_data ( ob_w_data ),
    .wr_b_ready ( ob_b_ready ),
    .wr_b_valid ( ob_b_valid ),
    .wr_b_resp ( ob_b_resp )
);

assign  c3_s1_axi_aclk                      = clk;
assign  c3_s1_axi_aresetn                   = !rst;
assign  c3_s1_axi_arid                      = 0;
assign  c3_s1_axi_arsize                    = 3'b010;   // 32-bits per beat
assign  c3_s1_axi_arburst                   = 2'b01;    // INCR
assign  c3_s1_axi_arlock                    = 1'b0;
assign  c3_s1_axi_arcache                   = 4'b0011;  // modifiable, bufferable
assign  c3_s1_axi_arprot                    = 3'b000;   // unprivileged, secure
assign  c3_s1_axi_arqos                     = 4'b0000;  // no QoS

// ** Outbound Read DMA **

wire                    int_dmard;

reg                     apb_sel_dmard;
wire                    apb_ready_dmard;
wire    [31:0]          apb_rdata_dmard;

wire                    dmard_cmd_ar_ready;
wire                    dmard_cmd_ar_valid;
wire    [CMD_ADDR-1:0]  dmard_cmd_ar_addr;
wire    [CMD_LEN-1:0]   dmard_cmd_ar_len;
wire                    dmard_cmd_r_ready;
wire                    dmard_cmd_r_valid;
wire                    dmard_cmd_r_last;
wire    [31:0]          dmard_cmd_r_data;
wire    [1:0]           dmard_cmd_r_resp;

wire                    dmard_data_ar_ready;
wire                    dmard_data_ar_valid;
wire    [OB_ADDR-1:0]   dmard_data_ar_addr;
wire    [OB_LEN-1:0]    dmard_data_ar_len;
wire                    dmard_data_r_ready;
wire                    dmard_data_r_valid;
wire                    dmard_data_r_last;
wire    [31:0]          dmard_data_r_data;
wire    [1:0]           dmard_data_r_resp;

dlsc_dma_core #(
    .APB_ADDR       ( APB_ADDR ),
    .CMD_ADDR       ( CMD_ADDR ),
    .CMD_LEN        ( CMD_LEN ),
    .READ_ADDR      ( OB_ADDR ),
    .READ_LEN       ( OB_LEN ),
    .READ_MOT       ( 16 ),
    .WRITE_ADDR     ( MIG_ADDR ),
    .WRITE_LEN      ( MIG_LEN ),
    .WRITE_MOT      ( 16 ),
    .DATA           ( 32 ),
    .BUFFER_SIZE    ( 2048 ),
    .TRIGGERS       ( 1 )
) dlsc_dma_core_outbound_read (
    .clk ( clk ),
    .rst ( rst ),
    .int_out ( int_dmard ),
    .trig_in ( 1'b0 ),
    .trig_in_ack (  ),
    .trig_out (  ),
    .trig_out_ack ( 1'b0 ),
    .apb_sel ( apb_sel_dmard ),
    .apb_enable ( apb_enable ),
    .apb_write ( apb_write ),
    .apb_addr ( apb_addr ),
    .apb_wdata ( apb_wdata ),
    .apb_rdata ( apb_rdata_dmard ),
    .apb_ready ( apb_ready_dmard ),
    .cmd_ar_ready ( dmard_cmd_ar_ready ),
    .cmd_ar_valid ( dmard_cmd_ar_valid ),
    .cmd_ar_addr ( dmard_cmd_ar_addr ),
    .cmd_ar_len ( dmard_cmd_ar_len ),
    .cmd_r_ready ( dmard_cmd_r_ready ),
    .cmd_r_valid ( dmard_cmd_r_valid ),
    .cmd_r_last ( dmard_cmd_r_last ),
    .cmd_r_data ( dmard_cmd_r_data ),
    .cmd_r_resp ( dmard_cmd_r_resp ),
    .rd_ar_ready ( dmard_data_ar_ready ),
    .rd_ar_valid ( dmard_data_ar_valid ),
    .rd_ar_addr ( dmard_data_ar_addr ),
    .rd_ar_len ( dmard_data_ar_len ),
    .rd_r_ready ( dmard_data_r_ready ),
    .rd_r_valid ( dmard_data_r_valid ),
    .rd_r_last ( dmard_data_r_last ),
    .rd_r_data ( dmard_data_r_data ),
    .rd_r_resp ( dmard_data_r_resp ),
    .wr_aw_ready ( c3_s1_axi_awready ),
    .wr_aw_valid ( c3_s1_axi_awvalid ),
    .wr_aw_addr ( c3_s1_axi_awaddr ),
    .wr_aw_len ( c3_s1_axi_awlen ),
    .wr_w_ready ( c3_s1_axi_wready ),
    .wr_w_valid ( c3_s1_axi_wvalid ),
    .wr_w_last ( c3_s1_axi_wlast ),
    .wr_w_strb ( c3_s1_axi_wstrb ),
    .wr_w_data ( c3_s1_axi_wdata ),
    .wr_b_ready ( c3_s1_axi_bready ),
    .wr_b_valid ( c3_s1_axi_bvalid ),
    .wr_b_resp ( c3_s1_axi_bresp )
);

assign  c3_s1_axi_awid                      = 0;
assign  c3_s1_axi_awsize                    = 3'b010;   // 32-bits per beat
assign  c3_s1_axi_awburst                   = 2'b01;    // INCR
assign  c3_s1_axi_awlock                    = 1'b0;
assign  c3_s1_axi_awcache                   = 4'b0011;  // modifiable, bufferable
assign  c3_s1_axi_awprot                    = 3'b000;   // unprivileged, secure
assign  c3_s1_axi_awqos                     = 4'b0000;  // no QoS

// ** Command Router **

generate
if(LOCAL_DMA_DESC) begin:GEN_LOCAL_DMA_DESC

    dlsc_axi_router_rd #(
        .ADDR       ( ADDR ),
        .DATA       ( 32 ),
        .LEN        ( LEN ),
        .BUFFER     ( BUFFER ),
        .INPUTS     ( 2 ),
        .OUTPUTS    ( 1 )
    ) dlsc_axi_router_rd_dmacmd (
        .clk ( clk ),
        .rst ( rst ),
        .in_ar_ready ( { dmawr_cmd_ar_ready , dmard_cmd_ar_ready } ),
        .in_ar_valid ( { dmawr_cmd_ar_valid , dmard_cmd_ar_valid } ),
        .in_ar_addr ( { dmawr_cmd_ar_addr , dmard_cmd_ar_addr } ),
        .in_ar_len ( { dmawr_cmd_ar_len , dmard_cmd_ar_len } ),
        .in_r_ready ( { dmawr_cmd_r_ready , dmard_cmd_r_ready } ),
        .in_r_valid ( { dmawr_cmd_r_valid , dmard_cmd_r_valid } ),
        .in_r_last ( { dmawr_cmd_r_last , dmard_cmd_r_last } ),
        .in_r_data ( { dmawr_cmd_r_data , dmard_cmd_r_data } ),
        .in_r_resp ( { dmawr_cmd_r_resp , dmard_cmd_r_resp } ),
        .out_ar_ready ( c3_s2_axi_arready ),
        .out_ar_valid ( c3_s2_axi_arvalid ),
        .out_ar_addr ( c3_s2_axi_araddr ),
        .out_ar_len ( c3_s2_axi_arlen[LEN-1:0] ),
        .out_r_ready ( c3_s2_axi_rready ),
        .out_r_valid ( c3_s2_axi_rvalid ),
        .out_r_last ( c3_s2_axi_rlast ),
        .out_r_data ( c3_s2_axi_rdata ),
        .out_r_resp ( c3_s2_axi_rresp )
    );

    // pass-through outbound read
    assign  dmard_data_ar_ready = ob_ar_ready;
    assign  ob_ar_valid         = dmard_data_ar_valid;
    assign  ob_ar_addr          = dmard_data_ar_addr;
    assign  ob_ar_len           = dmard_data_ar_len;
    assign  ob_r_ready          = dmard_data_r_ready;
    assign  dmard_data_r_valid  = ob_r_valid;
    assign  dmard_data_r_last   = ob_r_last;
    assign  dmard_data_r_data   = ob_r_data;
    assign  dmard_data_r_resp   = ob_r_resp;

end else begin:GEN_REMOTE_DMA_DESC

    dlsc_axi_router_rd #(
        .ADDR       ( OB_ADDR ),
        .DATA       ( 32 ),
        .LEN        ( OB_LEN ),
        .BUFFER     ( BUFFER ),
        .INPUTS     ( 3 ),
        .OUTPUTS    ( 1 )
    ) dlsc_axi_router_rd_dmacmd (
        .clk ( clk ),
        .rst ( rst ),
        .in_ar_ready ( { dmard_data_ar_ready , dmawr_cmd_ar_ready , dmard_cmd_ar_ready } ),
        .in_ar_valid ( { dmard_data_ar_valid , dmawr_cmd_ar_valid , dmard_cmd_ar_valid } ),
        .in_ar_addr ( { dmard_data_ar_addr , dmawr_cmd_ar_addr , dmard_cmd_ar_addr } ),
        .in_ar_len ( { dmard_data_ar_len , dmawr_cmd_ar_len , dmard_cmd_ar_len } ),
        .in_r_ready ( { dmard_data_r_ready , dmawr_cmd_r_ready , dmard_cmd_r_ready } ),
        .in_r_valid ( { dmard_data_r_valid , dmawr_cmd_r_valid , dmard_cmd_r_valid } ),
        .in_r_last ( { dmard_data_r_last , dmawr_cmd_r_last , dmard_cmd_r_last } ),
        .in_r_data ( { dmard_data_r_data , dmawr_cmd_r_data , dmard_cmd_r_data } ),
        .in_r_resp ( { dmard_data_r_resp , dmawr_cmd_r_resp , dmard_cmd_r_resp } ),
        .out_ar_ready ( ob_ar_ready ),
        .out_ar_valid ( ob_ar_valid ),
        .out_ar_addr ( ob_ar_addr ),
        .out_ar_len ( ob_ar_len ),
        .out_r_ready ( ob_r_ready ),
        .out_r_valid ( ob_r_valid ),
        .out_r_last ( ob_r_last ),
        .out_r_data ( ob_r_data ),
        .out_r_resp ( ob_r_resp )
    );

    // tie-off now-unused MIG signals
    assign  c3_s2_axi_arvalid                   = 1'b0;
    assign  c3_s2_axi_araddr                    = 0;
    assign  c3_s2_axi_arlen[LEN-1:0]            = 0;
    assign  c3_s2_axi_rready                    = 1'b0;

end
endgenerate

assign  c3_s2_axi_aclk                      = clk;
assign  c3_s2_axi_aresetn                   = !rst;
assign  c3_s2_axi_arid                      = 0;
assign  c3_s2_axi_arlen[MIG_LEN-1:LEN]      = 0;
assign  c3_s2_axi_arsize                    = 3'b010;   // 32-bits per beat
assign  c3_s2_axi_arburst                   = 2'b01;    // INCR
assign  c3_s2_axi_arlock                    = 1'b0;
assign  c3_s2_axi_arcache                   = 4'b0011;  // modifiable, bufferable
assign  c3_s2_axi_arprot                    = 3'b000;   // unprivileged, secure
assign  c3_s2_axi_arqos                     = 4'b0000;  // no QoS

// ** Tie-off unused MIG ports **
    
assign c3_s2_axi_awid = 0;
assign c3_s2_axi_awaddr = 0;
assign c3_s2_axi_awlen = 0;
assign c3_s2_axi_awsize = 0;
assign c3_s2_axi_awburst = 0;
assign c3_s2_axi_awlock = 0;
assign c3_s2_axi_awcache = 0;
assign c3_s2_axi_awprot = 0;
assign c3_s2_axi_awqos = 0;
assign c3_s2_axi_awvalid = 0;
assign c3_s2_axi_wdata = 0;
assign c3_s2_axi_wstrb = 0;
assign c3_s2_axi_wlast = 0;
assign c3_s2_axi_wvalid = 0;
assign c3_s2_axi_bready = 0;
    
assign c3_s3_axi_aclk = clk;
assign c3_s3_axi_aresetn = !rst;
assign c3_s3_axi_awid = 0;
assign c3_s3_axi_awaddr = 0;
assign c3_s3_axi_awlen = 0;
assign c3_s3_axi_awsize = 0;
assign c3_s3_axi_awburst = 0;
assign c3_s3_axi_awlock = 0;
assign c3_s3_axi_awcache = 0;
assign c3_s3_axi_awprot = 0;
assign c3_s3_axi_awqos = 0;
assign c3_s3_axi_awvalid = 0;
assign c3_s3_axi_wdata = 0;
assign c3_s3_axi_wstrb = 0;
assign c3_s3_axi_wlast = 0;
assign c3_s3_axi_wvalid = 0;
assign c3_s3_axi_bready = 0;
assign c3_s3_axi_arid = 0;
assign c3_s3_axi_araddr = 0;
assign c3_s3_axi_arlen = 0;
assign c3_s3_axi_arsize = 0;
assign c3_s3_axi_arburst = 0;
assign c3_s3_axi_arlock = 0;
assign c3_s3_axi_arcache = 0;
assign c3_s3_axi_arprot = 0;
assign c3_s3_axi_arqos = 0;
assign c3_s3_axi_arvalid = 0;
assign c3_s3_axi_rready = 0;

// ** APB decoding **

reg    apb_sel_null;
wire   apb_ready_null   = apb_sel_null && apb_enable;

assign apb_ready        = apb_ready_pcie    | apb_ready_dmard   | apb_ready_dmawr   | apb_ready_null;
assign apb_rdata        = apb_rdata_pcie    | apb_rdata_dmard   | apb_rdata_dmawr;
assign apb_slverr       = apb_slverr_pcie;

always @* begin
    apb_sel_pcie    = 1'b0;
    apb_sel_dmard   = 1'b0;
    apb_sel_dmawr   = 1'b0;
    apb_sel_null    = 1'b0;

    if(apb_sel) begin
        case(apb_addr[19:12])
            0: apb_sel_pcie     = 1'b1; // PCIe registers
            1: apb_sel_pcie     = 1'b1; // PCIe config space
            2: apb_sel_dmard    = 1'b1;
            3: apb_sel_dmawr    = 1'b1;
            default: apb_sel_null = 1'b1;
        endcase
    end
end

assign apb_int_in   = { int_dmawr, int_dmard, int_pcie };

endmodule

