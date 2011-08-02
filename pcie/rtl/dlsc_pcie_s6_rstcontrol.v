
module dlsc_pcie_s6_rstcontrol (
    // PCIe side
    input   wire                pcie_rst,       // PCIe reset from pcie_clk domain

    // AXI/bridge side
    input   wire                clk,            // clock for AXI bus and bridge logic
    input   wire                rst,            // reset for AXI bus

    output  wire                cross_rst,      // reset for domain crossing logic

    output  reg                 bridge_rst,     // generated reset for bridge logic

    input   wire                axi_busy,       // flag indicating AXI transactions are outstanding
    output  reg                 axi_disable,    // prevent further AXI transactions
    output  reg                 axi_flush       // flush outstanding AXI transactions
);

`include "dlsc_synthesis.vh"

// synchronize pcie_rst

dlsc_syncflop #(
    .DATA           ( 1 ),
    .RESET          ( 1'b1 )
) dlsc_syncflop_pcie_rst (
    .in             ( pcie_rst ),
    .clk            ( clk ),
    .rst            ( rst ),
    .out            ( cross_rst )
);

// create bridge_rst

always @(posedge clk) begin
    if(rst) begin
        // if AXI bus is in reset, bridge must be in reset
        axi_disable     <= 1'b1;
        axi_flush       <= 1'b1;
        bridge_rst      <= 1'b1;
    end else begin
        if(cross_rst) begin
            // PCIe is in reset; disable AXI transactions
            axi_disable     <= 1'b1;
            axi_flush       <= 1'b0;
            bridge_rst      <= 1'b0;
        end
        if(axi_disable) begin
            // AXI disabled; flush
            axi_disable     <= 1'b1;
            axi_flush       <= 1'b1;
            bridge_rst      <= 1'b0;
        end
        if(axi_disable && axi_flush && !axi_busy) begin
            // done flushing; reset bridge
            axi_disable     <= 1'b1;
            axi_flush       <= 1'b1;
            bridge_rst      <= 1'b1;
        end
        if(!cross_rst && bridge_rst) begin
            // PCIe no longer in reset; release bridge from reset
            axi_disable     <= 1'b0;
            axi_flush       <= 1'b0;
            bridge_rst      <= 1'b0;
        end
    end
end

endmodule

