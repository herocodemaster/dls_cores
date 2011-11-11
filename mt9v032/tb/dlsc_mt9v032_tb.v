`timescale 1ns/1ps

module `DLSC_TB;

`include "dlsc_tb_top.vh"

localparam CAMERAS      = `PARAM_CAMERAS;
localparam SWAP         = `PARAM_SWAP;
localparam ADDR         = `PARAM_APB_ADDR;
localparam HDISP        = `PARAM_HDISP;
localparam VDISP        = `PARAM_VDISP;
localparam FIFO_ADDR    = `PARAM_FIFO_ADDR;

// PLL inputs
reg                 clk_in = 1'b0;
reg                 rst_in = 1'b1;

initial forever #2.5 clk_in = !clk_in;


// APB
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

// pipeline output

reg                     px_clk = 1'b0;
reg                     px_rst = 1'b1;

initial forever #4.0 px_clk = !px_clk;

reg     [CAMERAS-1:0]   px_ready;
wire    [CAMERAS-1:0]   px_valid;
wire    [(CAMERAS*10)-1:0] px_data_concat;

// camera models

localparam HPX          = 64;
localparam VPX          = 48;
localparam HBLANK       = 16;
localparam VBLANK       = 16;

wire    [CAMERAS-1:0]   in_p;
wire    [CAMERAS-1:0]   in_n;
wire    [CAMERAS-1:0]   clk_out;

wire    [9:0]           px_data [CAMERAS-1:0];

reg                     train = 1'b0;

genvar j;
generate
for(j=0;j<CAMERAS;j=j+1) begin:GEN_MODELS
    mt9v032_model #(
        .CLK_DELAY  ( 100.0 + j * 400.0 ),
        .HPX        ( HPX ),
        .VPX        ( VPX ),
        .HBLANK     ( HBLANK ),
        .VBLANK     ( VBLANK )
    ) mt9v032_model_inst (
        .clk    ( clk_out[j] ),
        .train  ( train ),
        .out_p  ( in_p[j] ),
        .out_n  ( in_n[j] )
    );
    assign px_data[j] = px_data_concat[ j*10 +: 10 ];
end
endgenerate

// DUT

`DLSC_DUT
`ifndef POST_SYNTHESIS_SIMULATION
#(
    .CAMERAS    ( CAMERAS ),
    .SWAP       ( SWAP ),
    .APB_ADDR   ( ADDR ),
    .HDISP      ( HDISP ),
    .VDISP      ( VDISP ),
    .FIFO_ADDR  ( FIFO_ADDR ),
    .SIM_TAPDELAY_VALUE ( 13 )
)
`endif
dut (
    .clk_in ( clk_in ),
    .rst_in ( rst_in ),
    .apb_clk ( apb_clk ),
    .apb_rst ( apb_rst ),
    .apb_addr ( {apb_addr,2'b00} ),
    .apb_sel ( apb_sel ),
    .apb_enable ( apb_enable ),
    .apb_write ( apb_write ),
    .apb_wdata ( apb_wdata ),
    .apb_strb ( apb_strb ),
    .apb_ready ( apb_ready ),
    .apb_rdata ( apb_rdata ),
    .apb_int_out ( int_out ),
    .px_clk ( px_clk ),
    .px_rst ( px_rst ),
    .px_ready ( px_ready ),
    .px_valid ( px_valid ),
    .px_data ( px_data_concat ),
    .in_p ( in_p ),
    .in_n ( in_n ),
    .clk_out ( clk_out )
);


initial forever begin
    #10000
    `dlsc_info(".");
end

localparam  REG_CONTROL     = 0,
            REG_STATUS      = 1,
            REG_INT_FLAGS   = 2,
            REG_INT_SELECT  = 3,
            REG_HDISP       = 4,
            REG_VDISP       = 5,
            REG_HDISP_OBS   = 6,
            REG_VDISP_OBS   = 7;

integer i;
reg [31:0] d;

initial begin
    rst_in      = 1'b1;
    train       = 1'b0;
    px_ready    = 0;
    #1000;
    @(posedge clk_in);
    rst_in      = 1'b0;
    @(posedge apb_clk);
    apb_rst     = 1'b0;
    @(posedge px_clk);
    px_rst      = 1'b0;
    px_ready    = {CAMERAS{1'b1}};

    `dlsc_info("deassert reset");

    #10000;
    
    `dlsc_info("setup cameras");

    @(posedge apb_clk);
    for(i=1;i<=CAMERAS;i=i+1) begin
        apb.write((i*16)+REG_HDISP,         HPX);
        apb.write((i*16)+REG_VDISP,         VPX);
        apb.write((i*16)+REG_INT_SELECT,    (1<<2));    // output_ready
        apb.write((i*16)+REG_CONTROL,       1);
    end

    for(i=1;i<=CAMERAS;i=i+1) begin
        apb.read((i*16)+REG_STATUS,d);
        `dlsc_info("REG_STATUS[%0d] = 0x%0x",i,d);
    end

    `dlsc_info("wait for interrupt");

    @(posedge int_out);

    `dlsc_info("output_ready!");

    @(posedge apb_clk);
    for(i=1;i<=CAMERAS;i=i+1) begin
        apb.write((i*16)+REG_INT_FLAGS,     (1<<2));
        apb.write((i*16)+REG_CONTROL,       3);
    end

    for(i=1;i<=CAMERAS;i=i+1) begin
        apb.read((i*16)+REG_STATUS,d);
        `dlsc_info("REG_STATUS[%0d] = 0x%0x",i,d);
    end

    #1000000;

    `dlsc_info("done");

    for(i=1;i<=CAMERAS;i=i+1) begin
        apb.read((i*16)+REG_STATUS,d);
        `dlsc_info("REG_STATUS[%0d] = 0x%0x",i,d);
        if( (d&7) == 7 ) begin
            `dlsc_okay("camera ready");
        end else begin
            `dlsc_error("camera not ready");
        end
    end
    

    `dlsc_finish;
end

initial begin
    #2000000;
    `dlsc_error("watchdog timeout");

    `dlsc_finish;
end

endmodule

