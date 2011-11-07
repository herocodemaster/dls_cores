
`timescale 1ps/1ps

module `DLSC_TB;

`include "dlsc_tb_top.vh"

// ** System **

wire                    clk200_p;
wire                    clk200_n;

reg     [3:0]           btn                 = 4'd0;
wire    [3:0]           led;
    
// ** VGA **

wire                    dvi_xclk_p;
wire                    dvi_xclk_n;
wire                    dvi_reset_b;
wire    [11:0]          dvi_d;
wire                    dvi_de;
wire                    dvi_h;
wire                    dvi_v;
wire                    dvi_gpio;
wire                    dvi_scl;
wire                    dvi_sda;

// ** MIG **

wire    [15:0]          mcb3_dram_dq;
wire    [12:0]          mcb3_dram_a;
wire    [2:0]           mcb3_dram_ba;
wire                    mcb3_dram_ras_n;
wire                    mcb3_dram_cas_n;
wire                    mcb3_dram_we_n;
wire                    mcb3_dram_odt;
wire                    mcb3_dram_reset_n;
wire                    mcb3_dram_cke;
wire                    mcb3_dram_dm;
wire                    mcb3_dram_udqs;
wire                    mcb3_dram_udqs_n;
wire                    mcb3_rzq;
wire                    mcb3_zio;
wire                    mcb3_dram_udm;
wire                    mcb3_dram_dqs;
wire                    mcb3_dram_dqs_n;
wire                    mcb3_dram_ck;
wire                    mcb3_dram_ck_n;

// ** PCIe **
// (signals driven by board.v)

wire                    pcie_clk_p;
wire                    pcie_clk_n;
reg                     pcie_reset_n        = 1'b0;

wire                    pci_exp_txp;
wire                    pci_exp_txn;
wire                    pci_exp_rxp;
wire                    pci_exp_rxn;

// ** Clocks **

reg                     clk200_src          = 1'b0;
assign                  clk200_p            = clk200_src;
assign                  clk200_n            = !clk200_src;

initial forever #2500 clk200_src = !clk200_src;

reg                     pcie_clk_src        = 1'b0;
assign                  pcie_clk_p          = pcie_clk_src;
assign                  pcie_clk_n          = !pcie_clk_src;

initial forever #4000 pcie_clk_src = !pcie_clk_src;

// ** Memory Model **
     
ddr3_model_c3 u_mem_c3(
    .ck         (mcb3_dram_ck),
    .ck_n       (mcb3_dram_ck_n),
    .cke        (mcb3_dram_cke),
    .cs_n       (1'b0),
    .ras_n      (mcb3_dram_ras_n),
    .cas_n      (mcb3_dram_cas_n),
    .we_n       (mcb3_dram_we_n),
    .dm_tdqs    ({mcb3_dram_udm,mcb3_dram_dm}),
    .ba         (mcb3_dram_ba),
    .addr       (mcb3_dram_a),
    .dq         (mcb3_dram_dq),
    .dqs        ({mcb3_dram_udqs,mcb3_dram_dqs}),
    .dqs_n      ({mcb3_dram_udqs_n,mcb3_dram_dqs_n}),
    .tdqs_n     (),
    .odt        (mcb3_dram_odt),
    .rst_n      (mcb3_dram_reset_n)
);

PULLDOWN zio_pulldown(.O(mcb_zio));
PULLDOWN rzq_pulldown(.O(mcb_rzq));

// ** DUT **

`DLSC_DUT dut (
    .clk200_p ( clk200_p ),
    .clk200_n ( clk200_n ),
    .btn ( btn ),
    .led ( led ),
    .dvi_xclk_p ( dvi_xclk_p ),
    .dvi_xclk_n ( dvi_xclk_n ),
    .dvi_reset_b ( dvi_reset_b ),
    .dvi_d ( dvi_d ),
    .dvi_de ( dvi_de ),
    .dvi_h ( dvi_h ),
    .dvi_v ( dvi_v ),
    .dvi_gpio ( dvi_gpio ),
    .dvi_scl ( dvi_scl ),
    .dvi_sda ( dvi_sda ),
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
    .mcb3_dram_dqs ( mcb3_dram_dqs ),
    .mcb3_dram_dqs_n ( mcb3_dram_dqs_n ),
    .mcb3_dram_ck ( mcb3_dram_ck ),
    .mcb3_dram_ck_n ( mcb3_dram_ck_n ),
    .pcie_clk_p ( pcie_clk_p ),
    .pcie_clk_n ( pcie_clk_n ),
    .pcie_reset_n ( pcie_reset_n ),
    .pci_exp_txp ( pci_exp_txp ),
    .pci_exp_txn ( pci_exp_txn ),
    .pci_exp_rxp ( pci_exp_rxp ),
    .pci_exp_rxn ( pci_exp_rxn )
);

initial begin

    `dlsc_info("resets asserted");
    btn             = 4'hF;
    pcie_reset_n    = 1'b0;

    repeat (500) @(posedge clk200_p);

    `dlsc_info("master_rst deasserted");
    btn             = 4'h0;

    repeat (500) @(posedge pcie_clk_p);
    
    `dlsc_info("pcie_reset_n deasserted");
    pcie_reset_n    = 1'b1;

end

always @(led) begin
    `dlsc_info("mig_ready:      %x",  led[0]);
    `dlsc_info("rst:            %x", !led[1]);
    `dlsc_info("user_reset_out: %x", !led[2]);
    `dlsc_info("trn_pending:    %x",  led[3]);
end

endmodule

