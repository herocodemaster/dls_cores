
module mt9v032_serdes #(
    parameter SWAP      = 0                         // set SWAP if p/n top-level ports are swapped
) (
    // clocks and resets
    input   wire                    rst,            // synchronous to clk
    input   wire                    rst_2x,         // synchronous to clk_2x
    input   wire                    rst_9x,         // synchronous to clk_9x
    input   wire                    clk,            // pixel clock
    input   wire                    clk_2x,         // clk * 2
    input   wire                    clk_9x,         // clk * 9
    input   wire                    clk_12x,        // clk * 12
    input   wire                    clk_36x,        // clk * 36
    input   wire                    strobe_12to2,   // serdes_strobe for clk_12x -> clk_2x
    input   wire                    strobe_36to9,   // serdes_strobe for clk_36x -> clk_9x

    // deserialized data
    output  wire    [9:0]           data,           // synchronous to clk
    output  wire                    train_done,

    // control
    input   wire                    inhibit_skew,   // prevents clock skew changes when asserted

    // LVDS data input from image sensor
    input   wire                    in_p,           // connect to top-level port
    input   wire                    in_n,           // connect to top-level port

    // single-ended clock output to image sensor
    output  wire                    clk_out,        // connect to top-level port
    
    // iodelay
    input   wire                    iod_rst,        // reset should only be applied once after initial calibration
    input   wire                    iod_mask,       // prevent inc/dec operations
    input   wire                    iod_cal,        // slave must be periodically re-calibrated
    input   wire                    iod_cal_master, // master should only be calibrated once at power-up
    output  wire                    iod_busy
);


// ISERDES
wire is_skew_en_pre;
wire is_skew_inc;
wire is_skew_ack;

wire is_skew_en = is_skew_en_pre && !inhibit_skew;

mt9v032_iserdes #(
    .SWAP   ( SWAP )
) mt9v032_iserdes_inst (
    .rst            ( rst ),
    .rst_2x         ( rst_2x ),
    .clk            ( clk ),
    .clk_2x         ( clk_2x ),
    .clk_12x        ( clk_12x ),
    .strobe_12to2   ( strobe_12to2 ),
    .in_p           ( in_p ),
    .in_n           ( in_n ),
    .data           ( data ),
    .train_done     ( train_done ),
    .iod_rst        ( iod_rst ),
    .iod_mask       ( iod_mask ),
    .iod_cal        ( iod_cal ),
    .iod_cal_master ( iod_cal_master ),
    .iod_busy       ( iod_busy ),
    .skew_en        ( is_skew_en_pre ),
    .skew_inc       ( is_skew_inc ),
    .skew_ack       ( is_skew_ack )
);


// OSERDES
wire os_skew_en;
wire os_skew_inc;
wire os_skew_ack;

mt9v032_oserdes mt9v032_oserdes_inst (
    .rst_9x         ( rst_9x ),
    .clk_9x         ( clk_9x ),
    .clk_36x        ( clk_36x ),
    .strobe_36to9   ( strobe_36to9 ),
    .clk_out        ( clk_out ),
    .skew_en        ( os_skew_en ),
    .skew_inc       ( os_skew_inc ),
    .skew_ack       ( os_skew_ack )
);

// synchronizers
dlsc_domaincross #(
    .DATA       ( 2 )
) dlsc_domaincross_9x (
    .in_clk     ( clk_2x ),
    .in_rst     ( rst_2x ),
    .in_data    ( { is_skew_inc, is_skew_en } ),
    .out_clk    ( clk_9x ),
    .out_rst    ( rst_9x ),
    .out_data   ( { os_skew_inc, os_skew_en } )
);

dlsc_domaincross #(
    .DATA       ( 1 )
) dlsc_domaincross_2x (
    .in_clk     ( clk_9x ),
    .in_rst     ( rst_9x ),
    .in_data    ( { os_skew_ack } ),
    .out_clk    ( clk_2x ),
    .out_rst    ( rst_2x ),
    .out_data   ( { is_skew_ack } )
);



//// synchronizers
//
//sync #(
//    .WIDTH  ( 1 ),
//    .DEPTH  ( 2 )
//) sync_skew_9x_2d (
//    .clk            ( clk_9x ),
//    .in             ( { is_skew_inc } ),
//    .out            ( { os_skew_inc } )
//);
//
//// delay _en by 1 more cycle, to guarantee _inc is valid when _en asserts
//sync #(
//    .WIDTH  ( 1 ),
//    .DEPTH  ( 3 )
//) sync_skew_9x_3d (
//    .clk            ( clk_9x ),
//    .in             ( { is_skew_en } ),
//    .out            ( { os_skew_en } )
//);
//
//sync #(
//    .WIDTH  ( 1 )
//) sync_skew_2x (
//    .clk            ( clk_2x ),
//    .in             ( { os_skew_ack } ),
//    .out            ( { is_skew_ack } )
//);


endmodule

