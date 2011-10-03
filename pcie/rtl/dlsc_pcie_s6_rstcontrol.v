
module dlsc_pcie_s6_rstcontrol (
    // PCIe side
    input   wire                pcie_rst,       // PCIe reset from pcie_clk domain

    // AXI/bridge side
    input   wire                clk,            // clock for AXI bus and bridge logic
    input   wire                rst,            // reset for AXI bus

    output  wire                cross_rst,      // reset for domain crossing logic

    output  wire                bridge_rst,     // generated reset for bridge logic

    input   wire                axi_busy,       // flag indicating AXI transactions are outstanding
    output  wire                axi_disable,    // prevent further AXI transactions
    output  wire                axi_flush       // flush outstanding AXI transactions
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

localparam  ST_DISABLE              = 3'b100,
            ST_FLUSH                = 3'b110,
            ST_RESET                = 3'b111,
            ST_ACTIVE               = 3'b000;

reg [2:0] st;

assign axi_disable  = st[2];
assign axi_flush    = st[1];
assign bridge_rst   = st[0];

always @(posedge clk) begin
    if(rst) begin
        // if AXI bus is in reset, bridge must be in reset
        st      <= ST_RESET;
    end else begin
        if(st == ST_ACTIVE && cross_rst) begin
            // PCIe is in reset; disable AXI transactions
            st      <= ST_DISABLE;
        end
        if(st == ST_DISABLE) begin
            // AXI disabled; flush
            st      <= ST_FLUSH;
        end
        if(st == ST_FLUSH && !axi_busy) begin
            // done flushing; reset bridge
            st      <= ST_RESET;
        end
        if(st == ST_RESET && !cross_rst) begin
            // PCIe no longer in reset; release bridge from reset
            st      <= ST_ACTIVE;
        end
    end
end

endmodule

