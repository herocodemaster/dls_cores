
module dlsc_mt9v032_core #(
    parameter SWAP                  = 0,            // set SWAP if p/n top-level ports are swapped
    parameter APB_ADDR              = 32,
    parameter HDISP                 = 752,
    parameter VDISP                 = 480,
    parameter SIM_TAPDELAY_VALUE    = 30
) (
    // clocks/resets from mt9v032_clocks
    // iserdes
    input   wire                    is_rst,         // synchronous to clk
    input   wire                    is_clk,         // px_clk * 2
    input   wire                    is_clk_fast,    // px_clk * 12
    input   wire                    is_strobe,      // serdes_strobe for is_clk_fast -> clk
    input   wire                    is_clk_en,      // half-rate enable (turns is_clk into px_clk)
    // oserdes
    input   wire                    os_rst,         // synchronous to os_clk
    input   wire                    os_clk,         // px_clk * 9
    input   wire                    os_clk_fast,    // px_clk * 36
    input   wire                    os_strobe,      // serdes_strobe for os_clk_fast -> os_clk
    
    // APB register bus (on is_clk)
    input   wire    [APB_ADDR-1:0]  apb_addr,
    input   wire                    apb_sel,
    input   wire                    apb_enable,
    input   wire                    apb_write,
    input   wire    [31:0]          apb_wdata,
    input   wire    [3:0]           apb_strb,
    output  wire                    apb_ready,
    output  wire    [31:0]          apb_rdata,
    output  wire                    int_out,

    // pixel pipeline output (on is_clk)
    input   wire                    px_disable,
    input   wire                    px_ready,
    output  wire                    px_valid,
    output  wire    [9:0]           px_data,
    
    // LVDS data inputs from image sensor
    input   wire                    in_p,           // connect to top-level port
    input   wire                    in_n,           // connect to top-level port

    // single-ended clock outputs to image sensor
    output  wire                    clk_out         // connect to top-level port
);

// ** control **

wire            is_rst_i;
wire            pipeline_enable;
wire            pipeline_overrun;
wire            pipeline_disabled;
wire    [9:0]   hdisp;
wire    [9:0]   vdisp;
wire    [9:0]   obs_hdisp;
wire    [9:0]   obs_vdisp;
wire            res_okay;
wire            res_error;
wire            sync_error;
wire            frame_start;
wire            frame_end;
wire            frame_valid;
wire            bitslip_mask;
wire            bitslip_okay;
wire            bitslip_error;
wire            pd_valid;
wire            pd_inc;
wire            iod_busy;
wire            iod_rst_slave;
wire            iod_rst_master;
wire            iod_cal_slave;
wire            iod_cal_master;
wire            iod_en;
wire            iod_inc;
wire            is_skew_en;
wire            is_skew_inc;
wire            is_skew_ack;

dlsc_mt9v032_control #(
    .APB_ADDR ( APB_ADDR ),
    .HDISP ( HDISP ),
    .VDISP ( VDISP )
) dlsc_mt9v032_control (
    .clk ( is_clk ),
    .rst_in ( is_rst ),
    .rst_out ( is_rst_i ),
    .apb_addr ( apb_addr ),
    .apb_sel ( apb_sel ),
    .apb_enable ( apb_enable ),
    .apb_write ( apb_write ),
    .apb_wdata ( apb_wdata ),
    .apb_strb ( apb_strb ),
    .apb_ready ( apb_ready ),
    .apb_rdata ( apb_rdata ),
    .int_out ( int_out ),
    .pipeline_enable ( pipeline_enable ),
    .pipeline_overrun ( pipeline_overrun ),
    .pipeline_disabled ( pipeline_disabled ),
    .hdisp ( hdisp ),
    .vdisp ( vdisp ),
    .obs_hdisp ( obs_hdisp ),
    .obs_vdisp ( obs_vdisp ),
    .res_okay ( res_okay ),
    .res_error ( res_error ),
    .sync_error ( sync_error ),
    .frame_start ( frame_start ),
    .frame_end ( frame_end ),
    .frame_valid ( frame_valid ),
    .bitslip_mask ( bitslip_mask ),
    .bitslip_okay ( bitslip_okay ),
    .bitslip_error ( bitslip_error ),
    .pd_valid ( pd_valid ),
    .pd_inc ( pd_inc ),
    .iod_busy ( iod_busy ),
    .iod_rst_slave ( iod_rst_slave ),
    .iod_rst_master ( iod_rst_master ),
    .iod_cal_slave ( iod_cal_slave ),
    .iod_cal_master ( iod_cal_master ),
    .iod_en ( iod_en ),
    .iod_inc ( iod_inc ),
    .skew_en ( is_skew_en ),
    .skew_inc ( is_skew_inc ),
    .skew_ack ( is_skew_ack )
);

// ** oserdes **

wire            os_rst_i;

wire            os_skew_en;
wire            os_skew_inc;
wire            os_skew_ack;

dlsc_mt9v032_oserdes dlsc_mt9v032_oserdes (
    .os_rst ( os_rst_i ),
    .os_clk ( os_clk ),
    .os_clk_fast ( os_clk_fast ),
    .os_strobe ( os_strobe ),
    .clk_out ( clk_out ),
    .skew_en ( os_skew_en ),
    .skew_inc ( os_skew_inc ),
    .skew_ack ( os_skew_ack )
);

// synchronize skew control
// (skew_inc is set 1 cycle before skew_en, so it will make it to _os domain
// before skew_en - even if syncflops aren't perfectly matched)

wire            os_is_rst_i;
assign          os_rst_i        = os_rst || os_is_rst_i;

dlsc_syncflop #(
    .DATA       ( 3 ),
    .RESET      ( 3'b001 )
) dlsc_syncflop_os (
    .in         ( { is_skew_inc, is_skew_en,    is_rst_i } ),
    .clk        ( os_clk ),
    .rst        ( os_rst ),
    .out        ( { os_skew_inc, os_skew_en, os_is_rst_i } )
);

dlsc_syncflop #(
    .DATA       ( 1 ),
    .RESET      ( 1'b0 )
) dlsc_syncflop_is (
    .in         ( os_skew_ack ),
    .clk        ( is_clk ),
    .rst        ( is_rst ),
    .out        ( is_skew_ack )
);


// ** iserdes **

wire    [9:0]   is_data;

dlsc_mt9v032_iserdes #(
    .SWAP ( SWAP ),
    .SIM_TAPDELAY_VALUE ( SIM_TAPDELAY_VALUE )
) dlsc_mt9v032_iserdes (
    .rst ( is_rst_i ),
    .clk ( is_clk ),
    .clk_en ( is_clk_en ),
    .clk_fast ( is_clk_fast ),
    .strobe ( is_strobe ),
    .in_p ( in_p ),
    .in_n ( in_n ),
    .out_data ( is_data ),
    .bitslip_mask ( bitslip_mask ),
    .bitslip_okay ( bitslip_okay ),
    .bitslip_error ( bitslip_error ),
    .pd_valid ( pd_valid ),
    .pd_inc ( pd_inc ),
    .iod_rst_slave ( iod_rst_slave ),
    .iod_rst_master ( iod_rst_master ),
    .iod_cal_slave ( iod_cal_slave ),
    .iod_cal_master ( iod_cal_master ),
    .iod_busy ( iod_busy ),
    .iod_en ( iod_en ),
    .iod_inc ( iod_inc )
);


// ** timing/decoding **

wire            px_valid_pre;

assign          px_valid            = (px_valid_pre && is_clk_en && pipeline_enable);
assign          pipeline_overrun    = px_valid && !px_ready && !px_disable;
assign          pipeline_disabled   = px_disable;

dlsc_mt9v032_timing dlsc_mt9v032_timing (
    .clk ( is_clk ),
    .clk_en ( is_clk_en ),
    .rst ( is_rst_i ),
    .hdisp ( hdisp ),
    .vdisp ( vdisp ),
    .obs_hdisp ( obs_hdisp ),
    .obs_vdisp ( obs_vdisp ),
    .res_okay ( res_okay ),
    .res_error ( res_error ),
    .sync_error ( sync_error ),
    .frame_start ( frame_start ),
    .frame_end ( frame_end ),
    .in_data ( is_data ),
    .out_data ( px_data ),
    .out_px_valid ( px_valid_pre ),
    .out_line_valid (  ),
    .out_frame_valid ( frame_valid )
);

endmodule

