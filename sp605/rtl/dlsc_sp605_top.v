
module dlsc_sp605_top (

    // ** System **
    
    input   wire                    clk200_p,
    input   wire                    clk200_n,
    
    input   wire    [3:0]           btn,
    output  wire    [3:0]           led,

    // ** VGA **

    output  wire                    dvi_xclk_p,
    output  wire                    dvi_xclk_n,
    output  wire                    dvi_reset_b,
    output  wire    [11:0]          dvi_d,
    output  wire                    dvi_de,
    output  wire                    dvi_h,
    output  wire                    dvi_v,
    inout   wire                    dvi_gpio,
    inout   wire                    dvi_scl,
    inout   wire                    dvi_sda,

    // ** MIG **
   
    inout   wire    [15:0]          mcb3_dram_dq,
    output  wire    [12:0]          mcb3_dram_a,
    output  wire    [2:0]           mcb3_dram_ba,
    output  wire                    mcb3_dram_ras_n,
    output  wire                    mcb3_dram_cas_n,
    output  wire                    mcb3_dram_we_n,
    output  wire                    mcb3_dram_odt,
    output  wire                    mcb3_dram_reset_n,
    output  wire                    mcb3_dram_cke,
    output  wire                    mcb3_dram_dm,
    inout   wire                    mcb3_dram_udqs,
    inout   wire                    mcb3_dram_udqs_n,
    inout   wire                    mcb3_rzq,
    inout   wire                    mcb3_zio,
    output  wire                    mcb3_dram_udm,
    inout   wire                    mcb3_dram_dqs,
    inout   wire                    mcb3_dram_dqs_n,
    output  wire                    mcb3_dram_ck,
    output  wire                    mcb3_dram_ck_n,

    // ** PCIe **

    input   wire                    pcie_clk_p,
    input   wire                    pcie_clk_n,
    input   wire                    pcie_reset_n,
  
    output  wire                    pci_exp_txp,
    output  wire                    pci_exp_txn,
    input   wire                    pci_exp_rxp,
    input   wire                    pci_exp_rxn
);

localparam MIG_ID           = 4;
localparam MIG_ADDR         = 32;
localparam MIG_LEN          = 8;

localparam APB_ADDR         = MIG_ADDR;

localparam OB_READ_CPLH     = 40;
localparam OB_READ_CPLD     = 467;

localparam BYTE_SWAP        = 0;
localparam LOCAL_DMA_DESC   = 0;    // DMA descriptors in host memory
localparam BUFFER           = 1;    // enable extra buffering in AXI routers


// ** APB **

wire                apb_clk;
wire                apb_rst;
wire    [APB_ADDR-1:0] apb_addr;
wire                apb_sel;
wire                apb_enable;
wire                apb_write;
wire    [31:0]      apb_wdata;
wire    [3:0]       apb_strb;


// ** Clocks **

wire                    clk200_buf;

IBUFGDS #(
    .DIFF_TERM  ( "TRUE" ),
    .IOSTANDARD ( "LVDS_25" )
) IBUFGDS_clk_200 (
    .O          ( clk200_buf ),
    .I          ( clk200_p ),
    .IB         ( clk200_n )
);

wire                    pcie_clk;
wire                    pcie_rst        = !pcie_reset_n;

IBUFDS pcie_clk_buf (
    .O  ( pcie_clk ),
    .I  ( pcie_clk_p ),
    .IB ( pcie_clk_n )
);

wire                    mig_rst         = btn[0] && btn[3];
wire                    mig_ready;

(* KEEP = "TRUE" *) wire clk;
(* KEEP = "TRUE" *) wire rst;

dlsc_sp605_clocks dlsc_sp605_clocks (
    .clk200_in      ( clk200_buf ),
    .rst_in         ( !mig_ready ),
    .clk            ( clk ),
    .rst            ( rst ),
    .px_clk         (  ),
    .px_rst         (  )
);


// ** DCM_CLKGEN for px_clk **

(* KEEP = "TRUE" *) wire px_clk;
(* KEEP = "TRUE" *) wire px_clk_n;
(* KEEP = "TRUE" *) wire px_rst;

wire                int_clkgen;

wire                apb_sel_clkgen;
wire                apb_ready_clkgen;
wire    [31:0]      apb_rdata_clkgen;

dlsc_dcm_clkgen #(
    .ADDR           ( APB_ADDR ),
    .ENABLE         ( 1 ),
    .CLK_IN_PERIOD  ( 5.0 ),
    .CLK_DIVIDE     ( 25 ),             // default px_clk of 24 MHz
    .CLK_MULTIPLY   ( 3 ),
    .CLK_MD_MAX     ( (166.0/200.0) ),  // max px_clk of 166 MHz
    .CLK_DIV_DIVIDE ( 2 )
) dlsc_dcm_clkgen_px_clk (
    .apb_clk        ( apb_clk ),
    .apb_rst        ( apb_rst ),
    .apb_addr       ( apb_addr ),
    .apb_sel        ( apb_sel_clkgen ),
    .apb_enable     ( apb_enable ),
    .apb_write      ( apb_write ),
    .apb_wdata      ( apb_wdata ),
    .apb_strb       ( apb_strb ),
    .apb_ready      ( apb_ready_clkgen ),
    .apb_rdata      ( apb_rdata_clkgen ),
    .apb_int_out    ( int_clkgen ),
    .clk_in         ( clk200_buf ),
    .rst_in         ( !mig_ready ),
    .clk            ( px_clk ),
    .clk_n          ( px_clk_n ),
    .clk_div        (  ),
    .rst            ( px_rst )
);


// ** MIG **
    
wire                    c3_s0_axi_aclk;
wire                    c3_s0_axi_aresetn;
wire    [MIG_ID-1:0]    c3_s0_axi_awid;
wire    [MIG_ADDR-1:0]  c3_s0_axi_awaddr;
wire    [7:0]           c3_s0_axi_awlen;
wire    [2:0]           c3_s0_axi_awsize;
wire    [1:0]           c3_s0_axi_awburst;
wire    [0:0]           c3_s0_axi_awlock;
wire    [3:0]           c3_s0_axi_awcache;
wire    [2:0]           c3_s0_axi_awprot;
wire    [3:0]           c3_s0_axi_awqos;
wire                    c3_s0_axi_awvalid;
wire                    c3_s0_axi_awready;
wire    [31:0]          c3_s0_axi_wdata;
wire    [3:0]           c3_s0_axi_wstrb;
wire                    c3_s0_axi_wlast;
wire                    c3_s0_axi_wvalid;
wire                    c3_s0_axi_wready;
wire    [MIG_ID-1:0]    c3_s0_axi_bid;
wire    [1:0]           c3_s0_axi_bresp;
wire                    c3_s0_axi_bvalid;
wire                    c3_s0_axi_bready;
wire    [MIG_ID-1:0]    c3_s0_axi_arid;
wire    [MIG_ADDR-1:0]  c3_s0_axi_araddr;
wire    [7:0]           c3_s0_axi_arlen;
wire    [2:0]           c3_s0_axi_arsize;
wire    [1:0]           c3_s0_axi_arburst;
wire    [0:0]           c3_s0_axi_arlock;
wire    [3:0]           c3_s0_axi_arcache;
wire    [2:0]           c3_s0_axi_arprot;
wire    [3:0]           c3_s0_axi_arqos;
wire                    c3_s0_axi_arvalid;
wire                    c3_s0_axi_arready;
wire    [MIG_ID-1:0]    c3_s0_axi_rid;
wire    [31:0]          c3_s0_axi_rdata;
wire    [1:0]           c3_s0_axi_rresp;
wire                    c3_s0_axi_rlast;
wire                    c3_s0_axi_rvalid;
wire                    c3_s0_axi_rready;
wire                    c3_s1_axi_aclk;
wire                    c3_s1_axi_aresetn;
wire    [MIG_ID-1:0]    c3_s1_axi_awid;
wire    [MIG_ADDR-1:0]  c3_s1_axi_awaddr;
wire    [7:0]           c3_s1_axi_awlen;
wire    [2:0]           c3_s1_axi_awsize;
wire    [1:0]           c3_s1_axi_awburst;
wire    [0:0]           c3_s1_axi_awlock;
wire    [3:0]           c3_s1_axi_awcache;
wire    [2:0]           c3_s1_axi_awprot;
wire    [3:0]           c3_s1_axi_awqos;
wire                    c3_s1_axi_awvalid;
wire                    c3_s1_axi_awready;
wire    [31:0]          c3_s1_axi_wdata;
wire    [3:0]           c3_s1_axi_wstrb;
wire                    c3_s1_axi_wlast;
wire                    c3_s1_axi_wvalid;
wire                    c3_s1_axi_wready;
wire    [MIG_ID-1:0]    c3_s1_axi_bid;
wire    [1:0]           c3_s1_axi_bresp;
wire                    c3_s1_axi_bvalid;
wire                    c3_s1_axi_bready;
wire    [MIG_ID-1:0]    c3_s1_axi_arid;
wire    [MIG_ADDR-1:0]  c3_s1_axi_araddr;
wire    [7:0]           c3_s1_axi_arlen;
wire    [2:0]           c3_s1_axi_arsize;
wire    [1:0]           c3_s1_axi_arburst;
wire    [0:0]           c3_s1_axi_arlock;
wire    [3:0]           c3_s1_axi_arcache;
wire    [2:0]           c3_s1_axi_arprot;
wire    [3:0]           c3_s1_axi_arqos;
wire                    c3_s1_axi_arvalid;
wire                    c3_s1_axi_arready;
wire    [MIG_ID-1:0]    c3_s1_axi_rid;
wire    [31:0]          c3_s1_axi_rdata;
wire    [1:0]           c3_s1_axi_rresp;
wire                    c3_s1_axi_rlast;
wire                    c3_s1_axi_rvalid;
wire                    c3_s1_axi_rready;
wire                    c3_s2_axi_aclk;
wire                    c3_s2_axi_aresetn;
wire    [MIG_ID-1:0]    c3_s2_axi_awid;
wire    [MIG_ADDR-1:0]  c3_s2_axi_awaddr;
wire    [7:0]           c3_s2_axi_awlen;
wire    [2:0]           c3_s2_axi_awsize;
wire    [1:0]           c3_s2_axi_awburst;
wire    [0:0]           c3_s2_axi_awlock;
wire    [3:0]           c3_s2_axi_awcache;
wire    [2:0]           c3_s2_axi_awprot;
wire    [3:0]           c3_s2_axi_awqos;
wire                    c3_s2_axi_awvalid;
wire                    c3_s2_axi_awready;
wire    [31:0]          c3_s2_axi_wdata;
wire    [3:0]           c3_s2_axi_wstrb;
wire                    c3_s2_axi_wlast;
wire                    c3_s2_axi_wvalid;
wire                    c3_s2_axi_wready;
wire    [MIG_ID-1:0]    c3_s2_axi_bid;
wire    [1:0]           c3_s2_axi_bresp;
wire                    c3_s2_axi_bvalid;
wire                    c3_s2_axi_bready;
wire    [MIG_ID-1:0]    c3_s2_axi_arid;
wire    [MIG_ADDR-1:0]  c3_s2_axi_araddr;
wire    [7:0]           c3_s2_axi_arlen;
wire    [2:0]           c3_s2_axi_arsize;
wire    [1:0]           c3_s2_axi_arburst;
wire    [0:0]           c3_s2_axi_arlock;
wire    [3:0]           c3_s2_axi_arcache;
wire    [2:0]           c3_s2_axi_arprot;
wire    [3:0]           c3_s2_axi_arqos;
wire                    c3_s2_axi_arvalid;
wire                    c3_s2_axi_arready;
wire    [MIG_ID-1:0]    c3_s2_axi_rid;
wire    [31:0]          c3_s2_axi_rdata;
wire    [1:0]           c3_s2_axi_rresp;
wire                    c3_s2_axi_rlast;
wire                    c3_s2_axi_rvalid;
wire                    c3_s2_axi_rready;
wire                    c3_s3_axi_aclk;
wire                    c3_s3_axi_aresetn;
wire    [MIG_ID-1:0]    c3_s3_axi_awid;
wire    [MIG_ADDR-1:0]  c3_s3_axi_awaddr;
wire    [7:0]           c3_s3_axi_awlen;
wire    [2:0]           c3_s3_axi_awsize;
wire    [1:0]           c3_s3_axi_awburst;
wire    [0:0]           c3_s3_axi_awlock;
wire    [3:0]           c3_s3_axi_awcache;
wire    [2:0]           c3_s3_axi_awprot;
wire    [3:0]           c3_s3_axi_awqos;
wire                    c3_s3_axi_awvalid;
wire                    c3_s3_axi_awready;
wire    [31:0]          c3_s3_axi_wdata;
wire    [3:0]           c3_s3_axi_wstrb;
wire                    c3_s3_axi_wlast;
wire                    c3_s3_axi_wvalid;
wire                    c3_s3_axi_wready;
wire    [MIG_ID-1:0]    c3_s3_axi_bid;
wire    [1:0]           c3_s3_axi_bresp;
wire                    c3_s3_axi_bvalid;
wire                    c3_s3_axi_bready;
wire    [MIG_ID-1:0]    c3_s3_axi_arid;
wire    [MIG_ADDR-1:0]  c3_s3_axi_araddr;
wire    [7:0]           c3_s3_axi_arlen;
wire    [2:0]           c3_s3_axi_arsize;
wire    [1:0]           c3_s3_axi_arburst;
wire    [0:0]           c3_s3_axi_arlock;
wire    [3:0]           c3_s3_axi_arcache;
wire    [2:0]           c3_s3_axi_arprot;
wire    [3:0]           c3_s3_axi_arqos;
wire                    c3_s3_axi_arvalid;
wire                    c3_s3_axi_arready;
wire    [MIG_ID-1:0]    c3_s3_axi_rid;
wire    [31:0]          c3_s3_axi_rdata;
wire    [1:0]           c3_s3_axi_rresp;
wire                    c3_s3_axi_rlast;
wire                    c3_s3_axi_rvalid;
wire                    c3_s3_axi_rready;

dlsc_sp605_mig
`ifdef SIMULATION
#(
    .C3_SIMULATION ( "TRUE" )
)
`endif
dlsc_sp605_mig (
    .mcb3_dram_dq ( mcb3_dram_dq ),
    .mcb3_dram_a ( mcb3_dram_a ),
    .mcb3_dram_ba ( mcb3_dram_ba ),
    .mcb3_dram_ras_n ( mcb3_dram_ras_n ),
    .mcb3_dram_cas_n ( mcb3_dram_cas_n ),
    .mcb3_dram_we_n ( mcb3_dram_we_n ),
    .mcb3_dram_odt ( mcb3_dram_odt ),
    .mcb3_dram_reset_n ( mcb3_dram_reset_n ),
    .mcb3_dram_cke ( mcb3_dram_cke ),
    .mcb3_dram_dm ( mcb3_dram_dm ),
    .mcb3_dram_udqs ( mcb3_dram_udqs ),
    .mcb3_dram_udqs_n ( mcb3_dram_udqs_n ),
    .mcb3_rzq ( mcb3_rzq ),
    .mcb3_zio ( mcb3_zio ),
    .mcb3_dram_udm ( mcb3_dram_udm ),
    .c3_sys_clk ( clk200_buf ),
    .c3_sys_rst_i ( mig_rst ),
    .c3_calib_done ( mig_ready ),
    .mcb3_dram_dqs ( mcb3_dram_dqs ),
    .mcb3_dram_dqs_n ( mcb3_dram_dqs_n ),
    .mcb3_dram_ck ( mcb3_dram_ck ),
    .mcb3_dram_ck_n ( mcb3_dram_ck_n ),
    .c3_s0_axi_aclk ( c3_s0_axi_aclk ),
    .c3_s0_axi_aresetn ( c3_s0_axi_aresetn ),
    .c3_s0_axi_awid ( c3_s0_axi_awid ),
    .c3_s0_axi_awaddr ( c3_s0_axi_awaddr ),
    .c3_s0_axi_awlen ( c3_s0_axi_awlen ),
    .c3_s0_axi_awsize ( c3_s0_axi_awsize ),
    .c3_s0_axi_awburst ( c3_s0_axi_awburst ),
    .c3_s0_axi_awlock ( c3_s0_axi_awlock ),
    .c3_s0_axi_awcache ( c3_s0_axi_awcache ),
    .c3_s0_axi_awprot ( c3_s0_axi_awprot ),
    .c3_s0_axi_awqos ( c3_s0_axi_awqos ),
    .c3_s0_axi_awvalid ( c3_s0_axi_awvalid ),
    .c3_s0_axi_awready ( c3_s0_axi_awready ),
    .c3_s0_axi_wdata ( c3_s0_axi_wdata ),
    .c3_s0_axi_wstrb ( c3_s0_axi_wstrb ),
    .c3_s0_axi_wlast ( c3_s0_axi_wlast ),
    .c3_s0_axi_wvalid ( c3_s0_axi_wvalid ),
    .c3_s0_axi_wready ( c3_s0_axi_wready ),
    .c3_s0_axi_bid ( c3_s0_axi_bid ),
    .c3_s0_axi_wid ( c3_s0_axi_wid ),
    .c3_s0_axi_bresp ( c3_s0_axi_bresp ),
    .c3_s0_axi_bvalid ( c3_s0_axi_bvalid ),
    .c3_s0_axi_bready ( c3_s0_axi_bready ),
    .c3_s0_axi_arid ( c3_s0_axi_arid ),
    .c3_s0_axi_araddr ( c3_s0_axi_araddr ),
    .c3_s0_axi_arlen ( c3_s0_axi_arlen ),
    .c3_s0_axi_arsize ( c3_s0_axi_arsize ),
    .c3_s0_axi_arburst ( c3_s0_axi_arburst ),
    .c3_s0_axi_arlock ( c3_s0_axi_arlock ),
    .c3_s0_axi_arcache ( c3_s0_axi_arcache ),
    .c3_s0_axi_arprot ( c3_s0_axi_arprot ),
    .c3_s0_axi_arqos ( c3_s0_axi_arqos ),
    .c3_s0_axi_arvalid ( c3_s0_axi_arvalid ),
    .c3_s0_axi_arready ( c3_s0_axi_arready ),
    .c3_s0_axi_rid ( c3_s0_axi_rid ),
    .c3_s0_axi_rdata ( c3_s0_axi_rdata ),
    .c3_s0_axi_rresp ( c3_s0_axi_rresp ),
    .c3_s0_axi_rlast ( c3_s0_axi_rlast ),
    .c3_s0_axi_rvalid ( c3_s0_axi_rvalid ),
    .c3_s0_axi_rready ( c3_s0_axi_rready ),
    .c3_s1_axi_aclk ( c3_s1_axi_aclk ),
    .c3_s1_axi_aresetn ( c3_s1_axi_aresetn ),
    .c3_s1_axi_awid ( c3_s1_axi_awid ),
    .c3_s1_axi_awaddr ( c3_s1_axi_awaddr ),
    .c3_s1_axi_awlen ( c3_s1_axi_awlen ),
    .c3_s1_axi_awsize ( c3_s1_axi_awsize ),
    .c3_s1_axi_awburst ( c3_s1_axi_awburst ),
    .c3_s1_axi_awlock ( c3_s1_axi_awlock ),
    .c3_s1_axi_awcache ( c3_s1_axi_awcache ),
    .c3_s1_axi_awprot ( c3_s1_axi_awprot ),
    .c3_s1_axi_awqos ( c3_s1_axi_awqos ),
    .c3_s1_axi_awvalid ( c3_s1_axi_awvalid ),
    .c3_s1_axi_awready ( c3_s1_axi_awready ),
    .c3_s1_axi_wdata ( c3_s1_axi_wdata ),
    .c3_s1_axi_wstrb ( c3_s1_axi_wstrb ),
    .c3_s1_axi_wlast ( c3_s1_axi_wlast ),
    .c3_s1_axi_wvalid ( c3_s1_axi_wvalid ),
    .c3_s1_axi_wready ( c3_s1_axi_wready ),
    .c3_s1_axi_bid ( c3_s1_axi_bid ),
    .c3_s1_axi_wid ( c3_s1_axi_wid ),
    .c3_s1_axi_bresp ( c3_s1_axi_bresp ),
    .c3_s1_axi_bvalid ( c3_s1_axi_bvalid ),
    .c3_s1_axi_bready ( c3_s1_axi_bready ),
    .c3_s1_axi_arid ( c3_s1_axi_arid ),
    .c3_s1_axi_araddr ( c3_s1_axi_araddr ),
    .c3_s1_axi_arlen ( c3_s1_axi_arlen ),
    .c3_s1_axi_arsize ( c3_s1_axi_arsize ),
    .c3_s1_axi_arburst ( c3_s1_axi_arburst ),
    .c3_s1_axi_arlock ( c3_s1_axi_arlock ),
    .c3_s1_axi_arcache ( c3_s1_axi_arcache ),
    .c3_s1_axi_arprot ( c3_s1_axi_arprot ),
    .c3_s1_axi_arqos ( c3_s1_axi_arqos ),
    .c3_s1_axi_arvalid ( c3_s1_axi_arvalid ),
    .c3_s1_axi_arready ( c3_s1_axi_arready ),
    .c3_s1_axi_rid ( c3_s1_axi_rid ),
    .c3_s1_axi_rdata ( c3_s1_axi_rdata ),
    .c3_s1_axi_rresp ( c3_s1_axi_rresp ),
    .c3_s1_axi_rlast ( c3_s1_axi_rlast ),
    .c3_s1_axi_rvalid ( c3_s1_axi_rvalid ),
    .c3_s1_axi_rready ( c3_s1_axi_rready ),
    .c3_s2_axi_aclk ( c3_s2_axi_aclk ),
    .c3_s2_axi_aresetn ( c3_s2_axi_aresetn ),
    .c3_s2_axi_awid ( c3_s2_axi_awid ),
    .c3_s2_axi_awaddr ( c3_s2_axi_awaddr ),
    .c3_s2_axi_awlen ( c3_s2_axi_awlen ),
    .c3_s2_axi_awsize ( c3_s2_axi_awsize ),
    .c3_s2_axi_awburst ( c3_s2_axi_awburst ),
    .c3_s2_axi_awlock ( c3_s2_axi_awlock ),
    .c3_s2_axi_awcache ( c3_s2_axi_awcache ),
    .c3_s2_axi_awprot ( c3_s2_axi_awprot ),
    .c3_s2_axi_awqos ( c3_s2_axi_awqos ),
    .c3_s2_axi_awvalid ( c3_s2_axi_awvalid ),
    .c3_s2_axi_awready ( c3_s2_axi_awready ),
    .c3_s2_axi_wdata ( c3_s2_axi_wdata ),
    .c3_s2_axi_wstrb ( c3_s2_axi_wstrb ),
    .c3_s2_axi_wlast ( c3_s2_axi_wlast ),
    .c3_s2_axi_wvalid ( c3_s2_axi_wvalid ),
    .c3_s2_axi_wready ( c3_s2_axi_wready ),
    .c3_s2_axi_bid ( c3_s2_axi_bid ),
    .c3_s2_axi_wid ( c3_s2_axi_wid ),
    .c3_s2_axi_bresp ( c3_s2_axi_bresp ),
    .c3_s2_axi_bvalid ( c3_s2_axi_bvalid ),
    .c3_s2_axi_bready ( c3_s2_axi_bready ),
    .c3_s2_axi_arid ( c3_s2_axi_arid ),
    .c3_s2_axi_araddr ( c3_s2_axi_araddr ),
    .c3_s2_axi_arlen ( c3_s2_axi_arlen ),
    .c3_s2_axi_arsize ( c3_s2_axi_arsize ),
    .c3_s2_axi_arburst ( c3_s2_axi_arburst ),
    .c3_s2_axi_arlock ( c3_s2_axi_arlock ),
    .c3_s2_axi_arcache ( c3_s2_axi_arcache ),
    .c3_s2_axi_arprot ( c3_s2_axi_arprot ),
    .c3_s2_axi_arqos ( c3_s2_axi_arqos ),
    .c3_s2_axi_arvalid ( c3_s2_axi_arvalid ),
    .c3_s2_axi_arready ( c3_s2_axi_arready ),
    .c3_s2_axi_rid ( c3_s2_axi_rid ),
    .c3_s2_axi_rdata ( c3_s2_axi_rdata ),
    .c3_s2_axi_rresp ( c3_s2_axi_rresp ),
    .c3_s2_axi_rlast ( c3_s2_axi_rlast ),
    .c3_s2_axi_rvalid ( c3_s2_axi_rvalid ),
    .c3_s2_axi_rready ( c3_s2_axi_rready ),
    .c3_s3_axi_aclk ( c3_s3_axi_aclk ),
    .c3_s3_axi_aresetn ( c3_s3_axi_aresetn ),
    .c3_s3_axi_awid ( c3_s3_axi_awid ),
    .c3_s3_axi_awaddr ( c3_s3_axi_awaddr ),
    .c3_s3_axi_awlen ( c3_s3_axi_awlen ),
    .c3_s3_axi_awsize ( c3_s3_axi_awsize ),
    .c3_s3_axi_awburst ( c3_s3_axi_awburst ),
    .c3_s3_axi_awlock ( c3_s3_axi_awlock ),
    .c3_s3_axi_awcache ( c3_s3_axi_awcache ),
    .c3_s3_axi_awprot ( c3_s3_axi_awprot ),
    .c3_s3_axi_awqos ( c3_s3_axi_awqos ),
    .c3_s3_axi_awvalid ( c3_s3_axi_awvalid ),
    .c3_s3_axi_awready ( c3_s3_axi_awready ),
    .c3_s3_axi_wdata ( c3_s3_axi_wdata ),
    .c3_s3_axi_wstrb ( c3_s3_axi_wstrb ),
    .c3_s3_axi_wlast ( c3_s3_axi_wlast ),
    .c3_s3_axi_wvalid ( c3_s3_axi_wvalid ),
    .c3_s3_axi_wready ( c3_s3_axi_wready ),
    .c3_s3_axi_bid ( c3_s3_axi_bid ),
    .c3_s3_axi_wid ( c3_s3_axi_wid ),
    .c3_s3_axi_bresp ( c3_s3_axi_bresp ),
    .c3_s3_axi_bvalid ( c3_s3_axi_bvalid ),
    .c3_s3_axi_bready ( c3_s3_axi_bready ),
    .c3_s3_axi_arid ( c3_s3_axi_arid ),
    .c3_s3_axi_araddr ( c3_s3_axi_araddr ),
    .c3_s3_axi_arlen ( c3_s3_axi_arlen ),
    .c3_s3_axi_arsize ( c3_s3_axi_arsize ),
    .c3_s3_axi_arburst ( c3_s3_axi_arburst ),
    .c3_s3_axi_arlock ( c3_s3_axi_arlock ),
    .c3_s3_axi_arcache ( c3_s3_axi_arcache ),
    .c3_s3_axi_arprot ( c3_s3_axi_arprot ),
    .c3_s3_axi_arqos ( c3_s3_axi_arqos ),
    .c3_s3_axi_arvalid ( c3_s3_axi_arvalid ),
    .c3_s3_axi_arready ( c3_s3_axi_arready ),
    .c3_s3_axi_rid ( c3_s3_axi_rid ),
    .c3_s3_axi_rdata ( c3_s3_axi_rdata ),
    .c3_s3_axi_rresp ( c3_s3_axi_rresp ),
    .c3_s3_axi_rlast ( c3_s3_axi_rlast ),
    .c3_s3_axi_rvalid ( c3_s3_axi_rvalid ),
    .c3_s3_axi_rready ( c3_s3_axi_rready )
);


// ** PCIe **

wire                    received_hot_reset;
wire                    user_clk_out;
wire                    user_reset_out;
wire                    user_lnk_up;
wire    [2:0]           fc_sel;
wire    [7:0]           fc_ph;
wire    [11:0]          fc_pd;
wire    [7:0]           fc_nph;
wire    [11:0]          fc_npd;
wire    [7:0]           fc_cplh;
wire    [11:0]          fc_cpld;
wire                    s_axis_tx_tready;
wire                    s_axis_tx_tvalid;
wire                    s_axis_tx_tlast;
wire    [31:0]          s_axis_tx_tdata;
wire    [3:0]           s_axis_tx_tuser;
wire    [5:0]           tx_buf_av;
wire                    tx_err_drop;
wire                    tx_cfg_req;
wire                    tx_cfg_gnt;
wire                    rx_np_ok;
wire                    m_axis_rx_tready;
wire                    m_axis_rx_tvalid;
wire                    m_axis_rx_tlast;
wire    [31:0]          m_axis_rx_tdata;
wire    [9:0]           m_axis_rx_tuser;
wire                    cfg_rd_en;
wire    [9:0]           cfg_dwaddr;
wire                    cfg_rd_wr_done;
wire    [31:0]          cfg_do;
wire    [7:0]           cfg_bus_number;
wire    [4:0]           cfg_device_number;
wire    [2:0]           cfg_function_number;
wire    [15:0]          cfg_status;
wire    [15:0]          cfg_command;
wire    [15:0]          cfg_dstatus;
wire    [15:0]          cfg_dcommand;
wire    [15:0]          cfg_lstatus;
wire    [15:0]          cfg_lcommand;
wire    [2:0]           cfg_pcie_link_state;
wire                    cfg_to_turnoff;
wire                    cfg_turnoff_ok;
wire                    cfg_pm_wake;
wire                    cfg_trn_pending;
wire    [63:0]          cfg_dsn;
wire                    cfg_interrupt_msienable;
wire    [2:0]           cfg_interrupt_mmenable;
wire                    cfg_interrupt_rdy;
wire                    cfg_interrupt;
wire                    cfg_interrupt_assert;
wire    [7:0]           cfg_interrupt_di;
wire                    cfg_err_cpl_rdy;
wire    [47:0]          cfg_err_tlp_cpl_header;
wire                    cfg_err_posted;
wire                    cfg_err_locked;
wire                    cfg_err_cor;
wire                    cfg_err_cpl_abort;
wire                    cfg_err_cpl_timeout;
wire                    cfg_err_ecrc;
wire                    cfg_err_ur;

dlsc_sp605_pcie
`ifdef SIMULATION
#(
    .FAST_TRAIN ( "TRUE" )
)
`endif
dlsc_sp605_pcie (
    .pci_exp_txp ( pci_exp_txp ),
    .pci_exp_txn ( pci_exp_txn ),
    .pci_exp_rxp ( pci_exp_rxp ),
    .pci_exp_rxn ( pci_exp_rxn ),
    .user_lnk_up ( user_lnk_up ),
    .s_axis_tx_tready ( s_axis_tx_tready ),
    .s_axis_tx_tdata ( s_axis_tx_tdata ),
    .s_axis_tx_tkeep ( 4'hF ),
    .s_axis_tx_tuser ( s_axis_tx_tuser ),
    .s_axis_tx_tlast ( s_axis_tx_tlast ),
    .s_axis_tx_tvalid ( s_axis_tx_tvalid ),
    .tx_buf_av ( tx_buf_av ),
    .tx_err_drop ( tx_err_drop ),
    .tx_cfg_gnt ( tx_cfg_gnt ),
    .tx_cfg_req ( tx_cfg_req ),
    .m_axis_rx_tdata ( m_axis_rx_tdata ),
    .m_axis_rx_tkeep (  ),
    .m_axis_rx_tlast ( m_axis_rx_tlast ),
    .m_axis_rx_tvalid ( m_axis_rx_tvalid ),
    .m_axis_rx_tready ( m_axis_rx_tready ),
    .m_axis_rx_tuser ( m_axis_rx_tuser ),
    .rx_np_ok ( rx_np_ok ),
    .fc_sel ( fc_sel ),
    .fc_nph ( fc_nph ),
    .fc_npd ( fc_npd ),
    .fc_ph ( fc_ph ),
    .fc_pd ( fc_pd ),
    .fc_cplh ( fc_cplh ),
    .fc_cpld ( fc_cpld ),
    .cfg_do ( cfg_do ),
    .cfg_rd_wr_done ( cfg_rd_wr_done ),
    .cfg_dwaddr ( cfg_dwaddr ),
    .cfg_rd_en ( cfg_rd_en ),
    .cfg_err_ur ( cfg_err_ur ),
    .cfg_err_cor ( cfg_err_cor ),
    .cfg_err_ecrc ( cfg_err_ecrc ),
    .cfg_err_cpl_timeout ( cfg_err_cpl_timeout ),
    .cfg_err_cpl_abort ( cfg_err_cpl_abort ),
    .cfg_err_posted ( cfg_err_posted ),
    .cfg_err_locked ( cfg_err_locked ),
    .cfg_err_tlp_cpl_header ( cfg_err_tlp_cpl_header ),
    .cfg_err_cpl_rdy ( cfg_err_cpl_rdy ),
    .cfg_interrupt ( cfg_interrupt ),
    .cfg_interrupt_rdy ( cfg_interrupt_rdy ),
    .cfg_interrupt_assert ( cfg_interrupt_assert ),
    .cfg_interrupt_do (  ),
    .cfg_interrupt_di ( cfg_interrupt_di ),
    .cfg_interrupt_mmenable ( cfg_interrupt_mmenable ),
    .cfg_interrupt_msienable ( cfg_interrupt_msienable ),
    .cfg_turnoff_ok ( cfg_turnoff_ok ),
    .cfg_to_turnoff ( cfg_to_turnoff ),
    .cfg_pm_wake ( cfg_pm_wake ),
    .cfg_pcie_link_state ( cfg_pcie_link_state ),
    .cfg_trn_pending ( cfg_trn_pending ),
    .cfg_dsn ( cfg_dsn ),
    .cfg_bus_number ( cfg_bus_number ),
    .cfg_device_number ( cfg_device_number ),
    .cfg_function_number ( cfg_function_number ),
    .cfg_status ( cfg_status ),
    .cfg_command ( cfg_command ),
    .cfg_dstatus ( cfg_dstatus ),
    .cfg_dcommand ( cfg_dcommand ),
    .cfg_lstatus ( cfg_lstatus ),
    .cfg_lcommand ( cfg_lcommand ),
    .sys_clk ( pcie_clk ),
    .sys_reset ( pcie_rst ),
    .user_clk_out ( user_clk_out ),
    .user_reset_out ( user_reset_out ),
    .received_hot_reset ( received_hot_reset )
);


// ** VGA **
    
wire                    px_en;
wire                    px_vsync;
wire                    px_hsync;
wire                    px_valid;
wire    [7:0]           px_r;
wire    [7:0]           px_g;
wire    [7:0]           px_b;

dlsc_sp605_ch7301c #(
    .DELAY_CLK          ( 48 ),
    .DELAY_DATA         ( 0 )
) dlsc_sp605_ch7301c (
    .px_clk ( px_clk ),
    .px_clk_n ( px_clk_n ),
    .px_en ( px_en ),
    .px_vsync ( px_vsync ),
    .px_hsync ( px_hsync ),
    .px_valid ( px_valid ),
    .px_r ( px_r ),
    .px_g ( px_g ),
    .px_b ( px_b ),
    .out_clk_p ( dvi_xclk_p ),
    .out_clk_n ( dvi_xclk_n ),
    .out_data ( dvi_d ),
    .out_de ( dvi_de ),
    .out_hsync_n ( dvi_h ),
    .out_vsync_n ( dvi_v )
);

assign                  dvi_reset_b = !(px_rst || btn[1]);

wire                    scl_in;
wire                    scl_out;
wire                    scl_oe;
wire                    sda_in;
wire                    sda_out;
wire                    sda_oe;

assign                  scl_in      = dvi_scl;
assign                  dvi_scl     = scl_oe ? scl_out : 1'bz;

assign                  sda_in      = dvi_sda;
assign                  dvi_sda     = sda_oe ? sda_out : 1'bz;


// ** Core **

dlsc_sp605_core #(
    .MIG_ID             ( MIG_ID ),
    .MIG_ADDR           ( MIG_ADDR ),
    .MIG_LEN            ( MIG_LEN ),
    .APB_ADDR           ( APB_ADDR ),
    .OB_READ_CPLH       ( OB_READ_CPLH ),
    .OB_READ_CPLD       ( OB_READ_CPLD ),
    .BYTE_SWAP          ( BYTE_SWAP ),
    .LOCAL_DMA_DESC     ( LOCAL_DMA_DESC ),
    .BUFFER             ( BUFFER )
) dlsc_sp605_core (
    .clk ( clk ),
    .rst ( rst ),
    .px_clk ( px_clk ),
    .px_rst ( px_rst ),
    .apb_clk ( apb_clk ),
    .apb_rst ( apb_rst ),
    .apb_addr ( apb_addr ),
    .apb_enable ( apb_enable ),
    .apb_write ( apb_write ),
    .apb_wdata ( apb_wdata ),
    .apb_strb ( apb_strb ),
    .int_clkgen ( int_clkgen ),
    .apb_sel_clkgen ( apb_sel_clkgen ),
    .apb_ready_clkgen ( apb_ready_clkgen ),
    .apb_rdata_clkgen ( apb_rdata_clkgen ),
    .px_en ( px_en ),
    .px_vsync ( px_vsync ),
    .px_hsync ( px_hsync ),
    .px_valid ( px_valid ),
    .px_r ( px_r ),
    .px_g ( px_g ),
    .px_b ( px_b ),
    .scl_in ( scl_in ),
    .scl_out ( scl_out ),
    .scl_oe ( scl_oe ),
    .sda_in ( sda_in ),
    .sda_out ( sda_out ),
    .sda_oe ( sda_oe ),
    .c3_s0_axi_aclk ( c3_s0_axi_aclk ),
    .c3_s0_axi_aresetn ( c3_s0_axi_aresetn ),
    .c3_s0_axi_awid ( c3_s0_axi_awid ),
    .c3_s0_axi_awaddr ( c3_s0_axi_awaddr ),
    .c3_s0_axi_awlen ( c3_s0_axi_awlen ),
    .c3_s0_axi_awsize ( c3_s0_axi_awsize ),
    .c3_s0_axi_awburst ( c3_s0_axi_awburst ),
    .c3_s0_axi_awlock ( c3_s0_axi_awlock ),
    .c3_s0_axi_awcache ( c3_s0_axi_awcache ),
    .c3_s0_axi_awprot ( c3_s0_axi_awprot ),
    .c3_s0_axi_awqos ( c3_s0_axi_awqos ),
    .c3_s0_axi_awvalid ( c3_s0_axi_awvalid ),
    .c3_s0_axi_awready ( c3_s0_axi_awready ),
    .c3_s0_axi_wdata ( c3_s0_axi_wdata ),
    .c3_s0_axi_wstrb ( c3_s0_axi_wstrb ),
    .c3_s0_axi_wlast ( c3_s0_axi_wlast ),
    .c3_s0_axi_wvalid ( c3_s0_axi_wvalid ),
    .c3_s0_axi_wready ( c3_s0_axi_wready ),
    .c3_s0_axi_bid ( c3_s0_axi_bid ),
    .c3_s0_axi_bresp ( c3_s0_axi_bresp ),
    .c3_s0_axi_bvalid ( c3_s0_axi_bvalid ),
    .c3_s0_axi_bready ( c3_s0_axi_bready ),
    .c3_s0_axi_arid ( c3_s0_axi_arid ),
    .c3_s0_axi_araddr ( c3_s0_axi_araddr ),
    .c3_s0_axi_arlen ( c3_s0_axi_arlen ),
    .c3_s0_axi_arsize ( c3_s0_axi_arsize ),
    .c3_s0_axi_arburst ( c3_s0_axi_arburst ),
    .c3_s0_axi_arlock ( c3_s0_axi_arlock ),
    .c3_s0_axi_arcache ( c3_s0_axi_arcache ),
    .c3_s0_axi_arprot ( c3_s0_axi_arprot ),
    .c3_s0_axi_arqos ( c3_s0_axi_arqos ),
    .c3_s0_axi_arvalid ( c3_s0_axi_arvalid ),
    .c3_s0_axi_arready ( c3_s0_axi_arready ),
    .c3_s0_axi_rid ( c3_s0_axi_rid ),
    .c3_s0_axi_rdata ( c3_s0_axi_rdata ),
    .c3_s0_axi_rresp ( c3_s0_axi_rresp ),
    .c3_s0_axi_rlast ( c3_s0_axi_rlast ),
    .c3_s0_axi_rvalid ( c3_s0_axi_rvalid ),
    .c3_s0_axi_rready ( c3_s0_axi_rready ),
    .c3_s1_axi_aclk ( c3_s1_axi_aclk ),
    .c3_s1_axi_aresetn ( c3_s1_axi_aresetn ),
    .c3_s1_axi_awid ( c3_s1_axi_awid ),
    .c3_s1_axi_awaddr ( c3_s1_axi_awaddr ),
    .c3_s1_axi_awlen ( c3_s1_axi_awlen ),
    .c3_s1_axi_awsize ( c3_s1_axi_awsize ),
    .c3_s1_axi_awburst ( c3_s1_axi_awburst ),
    .c3_s1_axi_awlock ( c3_s1_axi_awlock ),
    .c3_s1_axi_awcache ( c3_s1_axi_awcache ),
    .c3_s1_axi_awprot ( c3_s1_axi_awprot ),
    .c3_s1_axi_awqos ( c3_s1_axi_awqos ),
    .c3_s1_axi_awvalid ( c3_s1_axi_awvalid ),
    .c3_s1_axi_awready ( c3_s1_axi_awready ),
    .c3_s1_axi_wdata ( c3_s1_axi_wdata ),
    .c3_s1_axi_wstrb ( c3_s1_axi_wstrb ),
    .c3_s1_axi_wlast ( c3_s1_axi_wlast ),
    .c3_s1_axi_wvalid ( c3_s1_axi_wvalid ),
    .c3_s1_axi_wready ( c3_s1_axi_wready ),
    .c3_s1_axi_bid ( c3_s1_axi_bid ),
    .c3_s1_axi_bresp ( c3_s1_axi_bresp ),
    .c3_s1_axi_bvalid ( c3_s1_axi_bvalid ),
    .c3_s1_axi_bready ( c3_s1_axi_bready ),
    .c3_s1_axi_arid ( c3_s1_axi_arid ),
    .c3_s1_axi_araddr ( c3_s1_axi_araddr ),
    .c3_s1_axi_arlen ( c3_s1_axi_arlen ),
    .c3_s1_axi_arsize ( c3_s1_axi_arsize ),
    .c3_s1_axi_arburst ( c3_s1_axi_arburst ),
    .c3_s1_axi_arlock ( c3_s1_axi_arlock ),
    .c3_s1_axi_arcache ( c3_s1_axi_arcache ),
    .c3_s1_axi_arprot ( c3_s1_axi_arprot ),
    .c3_s1_axi_arqos ( c3_s1_axi_arqos ),
    .c3_s1_axi_arvalid ( c3_s1_axi_arvalid ),
    .c3_s1_axi_arready ( c3_s1_axi_arready ),
    .c3_s1_axi_rid ( c3_s1_axi_rid ),
    .c3_s1_axi_rdata ( c3_s1_axi_rdata ),
    .c3_s1_axi_rresp ( c3_s1_axi_rresp ),
    .c3_s1_axi_rlast ( c3_s1_axi_rlast ),
    .c3_s1_axi_rvalid ( c3_s1_axi_rvalid ),
    .c3_s1_axi_rready ( c3_s1_axi_rready ),
    .c3_s2_axi_aclk ( c3_s2_axi_aclk ),
    .c3_s2_axi_aresetn ( c3_s2_axi_aresetn ),
    .c3_s2_axi_awid ( c3_s2_axi_awid ),
    .c3_s2_axi_awaddr ( c3_s2_axi_awaddr ),
    .c3_s2_axi_awlen ( c3_s2_axi_awlen ),
    .c3_s2_axi_awsize ( c3_s2_axi_awsize ),
    .c3_s2_axi_awburst ( c3_s2_axi_awburst ),
    .c3_s2_axi_awlock ( c3_s2_axi_awlock ),
    .c3_s2_axi_awcache ( c3_s2_axi_awcache ),
    .c3_s2_axi_awprot ( c3_s2_axi_awprot ),
    .c3_s2_axi_awqos ( c3_s2_axi_awqos ),
    .c3_s2_axi_awvalid ( c3_s2_axi_awvalid ),
    .c3_s2_axi_awready ( c3_s2_axi_awready ),
    .c3_s2_axi_wdata ( c3_s2_axi_wdata ),
    .c3_s2_axi_wstrb ( c3_s2_axi_wstrb ),
    .c3_s2_axi_wlast ( c3_s2_axi_wlast ),
    .c3_s2_axi_wvalid ( c3_s2_axi_wvalid ),
    .c3_s2_axi_wready ( c3_s2_axi_wready ),
    .c3_s2_axi_bid ( c3_s2_axi_bid ),
    .c3_s2_axi_bresp ( c3_s2_axi_bresp ),
    .c3_s2_axi_bvalid ( c3_s2_axi_bvalid ),
    .c3_s2_axi_bready ( c3_s2_axi_bready ),
    .c3_s2_axi_arid ( c3_s2_axi_arid ),
    .c3_s2_axi_araddr ( c3_s2_axi_araddr ),
    .c3_s2_axi_arlen ( c3_s2_axi_arlen ),
    .c3_s2_axi_arsize ( c3_s2_axi_arsize ),
    .c3_s2_axi_arburst ( c3_s2_axi_arburst ),
    .c3_s2_axi_arlock ( c3_s2_axi_arlock ),
    .c3_s2_axi_arcache ( c3_s2_axi_arcache ),
    .c3_s2_axi_arprot ( c3_s2_axi_arprot ),
    .c3_s2_axi_arqos ( c3_s2_axi_arqos ),
    .c3_s2_axi_arvalid ( c3_s2_axi_arvalid ),
    .c3_s2_axi_arready ( c3_s2_axi_arready ),
    .c3_s2_axi_rid ( c3_s2_axi_rid ),
    .c3_s2_axi_rdata ( c3_s2_axi_rdata ),
    .c3_s2_axi_rresp ( c3_s2_axi_rresp ),
    .c3_s2_axi_rlast ( c3_s2_axi_rlast ),
    .c3_s2_axi_rvalid ( c3_s2_axi_rvalid ),
    .c3_s2_axi_rready ( c3_s2_axi_rready ),
    .c3_s3_axi_aclk ( c3_s3_axi_aclk ),
    .c3_s3_axi_aresetn ( c3_s3_axi_aresetn ),
    .c3_s3_axi_awid ( c3_s3_axi_awid ),
    .c3_s3_axi_awaddr ( c3_s3_axi_awaddr ),
    .c3_s3_axi_awlen ( c3_s3_axi_awlen ),
    .c3_s3_axi_awsize ( c3_s3_axi_awsize ),
    .c3_s3_axi_awburst ( c3_s3_axi_awburst ),
    .c3_s3_axi_awlock ( c3_s3_axi_awlock ),
    .c3_s3_axi_awcache ( c3_s3_axi_awcache ),
    .c3_s3_axi_awprot ( c3_s3_axi_awprot ),
    .c3_s3_axi_awqos ( c3_s3_axi_awqos ),
    .c3_s3_axi_awvalid ( c3_s3_axi_awvalid ),
    .c3_s3_axi_awready ( c3_s3_axi_awready ),
    .c3_s3_axi_wdata ( c3_s3_axi_wdata ),
    .c3_s3_axi_wstrb ( c3_s3_axi_wstrb ),
    .c3_s3_axi_wlast ( c3_s3_axi_wlast ),
    .c3_s3_axi_wvalid ( c3_s3_axi_wvalid ),
    .c3_s3_axi_wready ( c3_s3_axi_wready ),
    .c3_s3_axi_bid ( c3_s3_axi_bid ),
    .c3_s3_axi_bresp ( c3_s3_axi_bresp ),
    .c3_s3_axi_bvalid ( c3_s3_axi_bvalid ),
    .c3_s3_axi_bready ( c3_s3_axi_bready ),
    .c3_s3_axi_arid ( c3_s3_axi_arid ),
    .c3_s3_axi_araddr ( c3_s3_axi_araddr ),
    .c3_s3_axi_arlen ( c3_s3_axi_arlen ),
    .c3_s3_axi_arsize ( c3_s3_axi_arsize ),
    .c3_s3_axi_arburst ( c3_s3_axi_arburst ),
    .c3_s3_axi_arlock ( c3_s3_axi_arlock ),
    .c3_s3_axi_arcache ( c3_s3_axi_arcache ),
    .c3_s3_axi_arprot ( c3_s3_axi_arprot ),
    .c3_s3_axi_arqos ( c3_s3_axi_arqos ),
    .c3_s3_axi_arvalid ( c3_s3_axi_arvalid ),
    .c3_s3_axi_arready ( c3_s3_axi_arready ),
    .c3_s3_axi_rid ( c3_s3_axi_rid ),
    .c3_s3_axi_rdata ( c3_s3_axi_rdata ),
    .c3_s3_axi_rresp ( c3_s3_axi_rresp ),
    .c3_s3_axi_rlast ( c3_s3_axi_rlast ),
    .c3_s3_axi_rvalid ( c3_s3_axi_rvalid ),
    .c3_s3_axi_rready ( c3_s3_axi_rready ),
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

assign led[0] = mig_ready;
assign led[1] = !rst;
assign led[2] = !user_reset_out;
assign led[3] = sda_oe || !dvi_reset_b || cfg_trn_pending;

endmodule

