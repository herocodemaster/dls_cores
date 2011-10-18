
module dlsc_pcie_s6_interrupts #(
    parameter APB_CLK_DOMAIN    = 0
) (
    // ** APB **
    
    // System
    input   wire                    apb_clk,
    input   wire                    apb_rst,
    input   wire                    apb_pcie_rst,   // pcie_rst synced to apb domain

    // Outbound interrupt
    input   wire                    apb_int_ob,     // interrupt to PCIe
    input   wire                    apb_int_redo,   // when pulsed, causes interrupt to be re-sent if still active

    // ** PCIe **

    // System
    input   wire                    pcie_clk,
    input   wire                    pcie_rst,
    
    // Interrupts
    input   wire                    pcie_cfg_interrupt_msienable,
    input   wire    [2:0]           pcie_cfg_interrupt_mmenable,
    input   wire                    pcie_cfg_interrupt_rdy,
    output  reg                     pcie_cfg_interrupt,
    output  reg                     pcie_cfg_interrupt_assert,
    output  wire    [7:0]           pcie_cfg_interrupt_di
);

// latch ack

wire        apb_int_redo_ready;
reg         apb_int_redo_valid;

always @(posedge apb_clk) begin
    if(apb_pcie_rst) begin
        apb_int_redo_valid   <= 1'b0;
    end else begin
        if(apb_int_redo_ready) begin
            apb_int_redo_valid   <= 1'b0;
        end
        if(apb_int_redo) begin
            apb_int_redo_valid   <= 1'b1;
        end
    end
end

// synchronize

wire        pcie_int_ob;
wire        pcie_int_redo_ready;
wire        pcie_int_redo_valid;

generate
if(APB_CLK_DOMAIN!=0) begin:GEN_ASYNC
    // synchronize apb_int_ob
    dlsc_syncflop #(
        .DATA       ( 1 ),
        .RESET      ( 1'b0 )
    ) dlsc_syncflop_int_ob (
        .in         ( apb_int_ob ),
        .clk        ( pcie_clk ),
        .rst        ( pcie_rst ),
        .out        ( pcie_int_ob )
    );
    // synchronize apb_int_redo
    dlsc_domaincross_rvh #(
        .DATA       ( 1 ),
        .RESET      ( 1'b0 )
    ) dlsc_domaincross_rvh_int_redo (
        .in_clk     ( apb_clk ),
        .in_rst     ( apb_pcie_rst ),
        .in_ready   ( apb_int_redo_ready ),
        .in_valid   ( apb_int_redo_valid ),
        .in_data    ( 1'b0 ),
        .out_clk    ( pcie_clk ),
        .out_rst    ( pcie_rst ),
        .out_ready  ( pcie_int_redo_ready ),
        .out_valid  ( pcie_int_redo_valid ),
        .out_data   (  )
    );        
end else begin:GEN_SYNC
    assign  pcie_int_ob         = apb_int_ob;
    assign  pcie_int_redo_valid = apb_int_redo_valid;
    assign  apb_int_redo_ready  = pcie_int_redo_ready;
end
endgenerate

// ** PCIe clock domain only from here **

// tie-off
assign          pcie_cfg_interrupt_di   = 8'd0; // always INTA/vector 0

// states
localparam  ST_IDLE         = 0,    // wait for interrupt to assert
            ST_MSI_SET      = 1,    // send MSI to core
            ST_MSI_WAIT     = 2,    // wait for interrupt to deassert
            ST_LEGACY_SET   = 3,    // send legacy assert to core
            ST_LEGACY_WAIT  = 4,    // wait for interrupt to deassert
            ST_LEGACY_CLEAR = 5;    // send legacy deassert to core

reg  [2:0]      st;
reg  [2:0]      next_st;

assign          pcie_int_redo_ready = (st == ST_IDLE) || !pcie_cfg_interrupt_msienable;

always @* begin

    next_st     = st;

    // common
    if(st == ST_IDLE) begin
        if(pcie_int_ob) begin
            if(pcie_cfg_interrupt_msienable) begin
                next_st     = ST_MSI_SET;
            end else begin
                next_st     = ST_LEGACY_SET;
            end
        end
    end

    // MSI
    if(st == ST_MSI_SET) begin
        if(pcie_cfg_interrupt_rdy) begin
            next_st     = ST_MSI_WAIT;
        end
    end
    if(st == ST_MSI_WAIT) begin
        if(!pcie_int_ob || pcie_int_redo_valid) begin
            next_st     = ST_IDLE;
        end
    end

    // Legacy
    if(st == ST_LEGACY_SET) begin
        if(pcie_cfg_interrupt_rdy) begin
            next_st     = ST_LEGACY_WAIT;
        end
    end
    if(st == ST_LEGACY_WAIT) begin
        if(!pcie_int_ob) begin
            next_st     = ST_LEGACY_CLEAR;
        end
    end
    if(st == ST_LEGACY_CLEAR) begin
        if(pcie_cfg_interrupt_rdy) begin
            next_st     = ST_IDLE;
        end
    end

end

always @(posedge pcie_clk) begin
    if(pcie_rst) begin
        st                          <= ST_IDLE;
        pcie_cfg_interrupt          <= 1'b0;
        pcie_cfg_interrupt_assert   <= 1'b0;
    end else begin
        st                          <= next_st;
        pcie_cfg_interrupt          <= 1'b0;
        pcie_cfg_interrupt_assert   <= 1'b0;
        if(next_st == ST_MSI_SET) begin
            pcie_cfg_interrupt          <= 1'b1;
            pcie_cfg_interrupt_assert   <= 1'b0;
        end
        if(next_st == ST_LEGACY_SET) begin
            pcie_cfg_interrupt          <= 1'b1;
            pcie_cfg_interrupt_assert   <= 1'b1;
        end
        if(next_st == ST_LEGACY_CLEAR) begin
            pcie_cfg_interrupt          <= 1'b1;
            pcie_cfg_interrupt_assert   <= 1'b0;
        end
    end
end


endmodule

