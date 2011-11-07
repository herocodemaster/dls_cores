
`timescale 1ps/1ps

module board;

// ** PCIe Model **
  
xilinx_pcie_2_0_rport_v6 #(
    .REF_CLK_FREQ   ( 1 ),      // 125 MHz
    .PL_FAST_TRAIN  ( "TRUE" ),
    .RX_LOG         ( 0 ),
    .TX_LOG         ( 1 ),
    .TRN_RX_TIMEOUT ( 5000 )
) RP (
    .sys_clk        ( `DLSC_TB.pcie_clk_p ),
    .sys_reset_n    ( `DLSC_TB.pcie_reset_n ),
    .pci_exp_txn    ( `DLSC_TB.pci_exp_rxn ),
    .pci_exp_txp    ( `DLSC_TB.pci_exp_rxp ),
    .pci_exp_rxn    ( `DLSC_TB.pci_exp_txn ),
    .pci_exp_rxp    ( `DLSC_TB.pci_exp_txp )
);

endmodule

