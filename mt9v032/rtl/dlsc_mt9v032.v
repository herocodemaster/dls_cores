
module dlsc_mt9v032 #(
    parameter CAMERAS               = 1,
    parameter SWAP                  = {CAMERAS{1'b0}},
    parameter APB_ADDR              = 32,
    parameter HDISP                 = 752,
    parameter VDISP                 = 480,
    parameter FIFO_ADDR             = 4,            // size of pipeline output FIFOs
    parameter SIM_TAPDELAY_VALUE    = 30
) (
    // inputs to PLL
    input   wire                    clk_in,         // 200 MHz input
    input   wire                    rst_in,
    
    // APB register bus
    input   wire                    apb_clk,
    input   wire                    apb_rst,
    input   wire    [APB_ADDR-1:0]  apb_addr,
    input   wire                    apb_sel,
    input   wire                    apb_enable,
    input   wire                    apb_write,
    input   wire    [31:0]          apb_wdata,
    input   wire    [3:0]           apb_strb,
    output  wire                    apb_ready,
    output  wire    [31:0]          apb_rdata,
    output  wire                    apb_int_out,

    // pipeline output
    input   wire                    px_clk,
    input   wire                    px_rst,
    input   wire    [CAMERAS-1:0]   px_ready,
    output  wire    [CAMERAS-1:0]   px_valid,
    output  wire    [(CAMERAS*10)-1:0] px_data,

    // LVDS data inputs from image sensors
    input   wire    [CAMERAS-1:0]   in_p,           // connect to top-level port
    input   wire    [CAMERAS-1:0]   in_n,           // connect to top-level port

    // single-ended clock outputs to image sensors
    output  wire    [CAMERAS-1:0]   clk_out         // connect to top-level port
);

// ** clocks **

// iserdes
wire            is_rst;         // synchronous to clk
wire            is_clk;         // px_clk * 2
wire            is_clk_fast;    // px_clk * 12
wire            is_strobe;      // serdes_strobe for is_clk_fast -> clk
wire            is_clk_en;      // half-rate enable (turns is_clk into px_clk)
// oserdes
wire            os_rst;         // synchronous to os_clk
wire            os_clk;         // px_clk * 9
wire            os_clk_fast;    // px_clk * 36
wire            os_strobe;      // serdes_strobe for os_clk_fast -> os_clk

dlsc_mt9v032_clocks dlsc_mt9v032_clocks (
    .clk_in         ( clk_in ),
    .rst_in         ( rst_in ),
    .is_rst         ( is_rst ),
    .is_clk         ( is_clk ),
    .is_clk_fast    ( is_clk_fast ),
    .is_strobe      ( is_strobe ),
    .is_clk_en      ( is_clk_en ),
    .os_rst         ( os_rst ),
    .os_clk         ( os_clk ),
    .os_clk_fast    ( os_clk_fast ),
    .os_strobe      ( os_strobe )
);


// ** top-level registers **
// TODO


// ** APB async crossing **
    
wire    [11:2]          is_apb_addr;
wire                    is_apb_sel;
wire                    is_apb_enable;
wire                    is_apb_write;
wire    [31:0]          is_apb_wdata;
wire    [3:0]           is_apb_strb;

reg     [CAMERAS-1:0]   is_apb_sel_cameras;
wire    [CAMERAS-1:0]   is_apb_ready_cameras;
wire    [31:0]          is_apb_rdata_cameras[CAMERAS-1:0];

reg                     is_apb_sel_null;
wire                    is_apb_ready_null = is_apb_sel_null && is_apb_enable;

wire                    is_apb_ready    = |is_apb_ready_cameras || is_apb_ready_null;
reg     [31:0]          is_apb_rdata;

integer i;
always @* begin
    is_apb_rdata        = 32'd0;
    is_apb_sel_cameras  = 0;
    for(i=0;i<CAMERAS;i=i+1) begin
        is_apb_rdata        = is_apb_rdata | is_apb_rdata_cameras[i];
        is_apb_sel_cameras[i] = is_apb_sel && (is_apb_addr[11:6] == (i+1));
    end
    is_apb_sel_null     = is_apb_sel && !(|is_apb_sel_cameras);
end

dlsc_apb_domaincross #(
    .DATA           ( 32 ),
    .ADDR           ( 10 )
) dlsc_apb_domaincross (
    .m_clk          ( apb_clk ),
    .m_rst          ( apb_rst ),
    .m_apb_addr     ( apb_addr[11:2] ),
    .m_apb_sel      ( apb_sel ),
    .m_apb_enable   ( apb_enable ),
    .m_apb_write    ( apb_write ),
    .m_apb_wdata    ( apb_wdata ),
    .m_apb_strb     ( apb_strb ),
    .m_apb_ready    ( apb_ready ),
    .m_apb_rdata    ( apb_rdata ),
    .m_apb_slverr   (  ),
    .s_clk          ( is_clk ),
    .s_rst          ( is_rst ),
    .s_apb_addr     ( is_apb_addr ),
    .s_apb_sel      ( is_apb_sel ),
    .s_apb_enable   ( is_apb_enable ),
    .s_apb_write    ( is_apb_write ),
    .s_apb_wdata    ( is_apb_wdata ),
    .s_apb_strb     ( is_apb_strb ),
    .s_apb_ready    ( is_apb_ready ),
    .s_apb_rdata    ( is_apb_rdata ),
    .s_apb_slverr   (  )
);

// synchronize interrupts

wire    [CAMERAS-1:0]   is_int_out_cameras;
wire                    is_int_out      = |is_int_out_cameras;

dlsc_syncflop #(
    .DATA       ( 1 ),
    .RST        ( 1'b0 )
) dlsc_syncflop_apb_int_out (
    .in         ( is_int_out ),
    .clk        ( apb_clk ),
    .rst        ( apb_rst ),
    .out        ( apb_int_out )
);

// synchronize px_rst to is_clk domain

wire            is_pipeline_disabled;

dlsc_syncflop #(
    .DATA       ( 1 ),
    .RESET      ( 1'b1 )
) dlsc_syncflop_pipeline_disabled (
    .in         ( px_rst ),
    .clk        ( is_clk ),
    .rst        ( is_rst ),
    .out        ( is_pipeline_disabled )
);


// ** camera interfaces **

genvar j;
generate
for(j=0;j<CAMERAS;j=j+1) begin:GEN_CAMERAS

    // output FIFO
    wire            wr_full;
    wire            wr_ready        = !wr_full;
    wire            wr_valid;
    wire    [9:0]   wr_data;

    wire            rd_empty;
    assign          px_valid[j]     = !rd_empty;

    dlsc_fifo_async #(
        .DATA           ( 10 ),
        .ADDR           ( FIFO_ADDR )
    ) dlsc_fifo_async (
        .wr_clk         ( is_clk ),
        .wr_rst         ( is_rst || is_pipeline_disabled ),
        .wr_push        ( wr_ready && wr_valid ),
        .wr_data        ( wr_data ),
        .wr_full        ( wr_full ),
        .wr_almost_full ( wr_almost_full ),
        .wr_free        (  ),
        .rd_clk         ( px_clk ),
        .rd_rst         ( px_rst ),
        .rd_pop         ( px_ready[j] && px_valid[j] ),
        .rd_data        ( px_data[ (j*10) +: 10 ] ),
        .rd_empty       ( rd_empty ),
        .rd_almost_empty(  ),
        .rd_count       (  )
    );

    // core
    dlsc_mt9v032_core #(
        .SWAP           ( SWAP[j] ),
        .APB_ADDR       ( 12 ),
        .HDISP          ( HDISP ),
        .VDISP          ( VDISP ),
        .SIM_TAPDELAY_VALUE ( SIM_TAPDELAY_VALUE )
    ) dlsc_mt9v032_core (
        .is_rst         ( is_rst ),
        .is_clk         ( is_clk ),
        .is_clk_fast    ( is_clk_fast ),
        .is_strobe      ( is_strobe ),
        .is_clk_en      ( is_clk_en ),
        .os_rst         ( os_rst ),
        .os_clk         ( os_clk ),
        .os_clk_fast    ( os_clk_fast ),
        .os_strobe      ( os_strobe ),
        .apb_addr       ( {is_apb_addr[11:2],2'b00} ),
        .apb_sel        ( is_apb_sel_cameras[j] ),
        .apb_enable     ( is_apb_enable ),
        .apb_write      ( is_apb_write ),
        .apb_wdata      ( is_apb_wdata ),
        .apb_strb       ( is_apb_strb ),
        .apb_ready      ( is_apb_ready_cameras[j] ),
        .apb_rdata      ( is_apb_rdata_cameras[j] ),
        .int_out        ( is_int_out_cameras[j] ),
        .px_disable     ( is_pipeline_disabled ),
        .px_ready       ( wr_ready ),
        .px_valid       ( wr_valid ),
        .px_data        ( wr_data ),
        .in_p           ( in_p[j] ),
        .in_n           ( in_n[j] ),
        .clk_out        ( clk_out[j] )
    );

end
endgenerate

endmodule

