`timescale 1ns/1ps

module dlsc_dcm_clkgen_tb;

`include "dlsc_tb_top.vh"

localparam ADDR             = `PARAM_ADDR;
localparam ENABLE           = `PARAM_ENABLE;
localparam CLK_IN_PERIOD    = `PARAM_CLK_IN_PERIOD;
localparam CLK_DIVIDE       = `PARAM_CLK_DIVIDE;
localparam CLK_MULTIPLY     = `PARAM_CLK_MULTIPLY;
localparam CLK_MD_MAX       = `PARAM_CLK_MD_MAX;
localparam CLK_DIV_DIVIDE   = `PARAM_CLK_DIV_DIVIDE;

reg                 clk_in = 1'b0;
reg                 rst_in = 1'b1;

initial forever #(CLK_IN_PERIOD/2) clk_in = !clk_in;

reg                 apb_clk = 1'b0;
reg                 apb_rst = 1'b1;

initial forever #5.0 apb_clk = !apb_clk;


wire    [ADDR-1:2]  apb_addr;
wire                apb_sel;
wire                apb_enable;
wire                apb_write;
wire    [31:0]      apb_wdata;
wire    [3:0]       apb_strb;
wire                apb_ready;
wire    [31:0]      apb_rdata;

wire                int_out;

wire                clk;
wire                clk_n;
wire                clk_div;
wire                rst;

`DLSC_DUT #(
    .ADDR           ( ADDR ),
    .ENABLE         ( ENABLE ),
    .CLK_IN_PERIOD  ( CLK_IN_PERIOD ),
    .CLK_DIVIDE     ( CLK_DIVIDE ),
    .CLK_MULTIPLY   ( CLK_MULTIPLY ),
    .CLK_MD_MAX     ( CLK_MD_MAX ),
    .CLK_DIV_DIVIDE ( CLK_DIV_DIVIDE )
) dut (
    .apb_clk        ( apb_clk ),
    .apb_rst        ( apb_rst ),
    .apb_addr       ( {apb_addr,2'b00} ),
    .apb_sel        ( apb_sel ),
    .apb_enable     ( apb_enable ),
    .apb_write      ( apb_write ),
    .apb_wdata      ( apb_wdata ),
    .apb_strb       ( apb_strb ),
    .apb_ready      ( apb_ready ),
    .apb_rdata      ( apb_rdata ),
    .apb_int_out    ( int_out ),
    .clk_in         ( clk_in ),
    .rst_in         ( rst_in ),
    .clk            ( clk ),
    .clk_n          ( clk_n ),
    .clk_div        ( clk_div ),
    .rst            ( rst )
);

dlsc_apb_bfm #(
    .ADDR           ( ADDR-2 ),
    .DATA           ( 32 )
) apb (
    .clk            ( apb_clk ),
    .rst            ( apb_rst ),
    .apb_addr       ( apb_addr ),
    .apb_sel        ( apb_sel ),
    .apb_enable     ( apb_enable ),
    .apb_write      ( apb_write ),
    .apb_wdata      ( apb_wdata ),
    .apb_strb       ( apb_strb ),
    .apb_ready      ( apb_ready ),
    .apb_rdata      ( apb_rdata ),
    .apb_slverr     ( 1'b0 )
);

localparam  REG_CONTROL     = 3'h0,
            REG_STATUS      = 3'h1,
            REG_INT_FLAGS   = 3'h2,
            REG_INT_SELECT  = 3'h3,
            REG_MULTIPLY    = 3'h4,
            REG_DIVIDE      = 3'h5;


initial forever begin
    #10000
    `dlsc_info(".");
end


initial begin
    rst_in      = 1'b1;
    apb_rst     = 1'b1;

    #100;

    @(posedge apb_clk);
    apb_rst     = 1'b0;
    @(posedge clk_in);
    rst_in      = 1'b0;

    #100;

    @(posedge apb_clk);
    apb.write(REG_INT_SELECT,32'h3);
    apb.write(REG_MULTIPLY,57-1);
    apb.write(REG_DIVIDE,43-1);
    apb.write(REG_CONTROL,32'h1);

    @(posedge int_out);
    if(!rst) begin
        `dlsc_okay("output active");
    end else begin
        `dlsc_error("reset not deasserted when enabled set");
    end

    @(posedge apb_clk);
    apb.write(REG_INT_FLAGS,32'h1);
    @(posedge apb_clk);
    if(int_out) begin
        `dlsc_error("interrupt not cleared");
    end

    #2000;

    @(posedge apb_clk);
    apb.write(REG_CONTROL,32'h0);

    @(posedge int_out);
    if(rst) begin
        `dlsc_okay("reset asserted; output disabled");
    end else begin
        `dlsc_error("reset not asserted when disabled set");
    end
    apb.write(REG_INT_FLAGS,32'h2);
    @(posedge apb_clk);
    if(int_out) begin
        `dlsc_error("interrupt not cleared");
    end

    #2000;

    `dlsc_finish;
end

initial begin
    #1000000;
    `dlsc_error("watchdog timeout");

    `dlsc_finish;
end

endmodule

