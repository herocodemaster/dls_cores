
module mt9v032_top #(
    parameter WIDTH     = 1,
    parameter SWAP      = {WIDTH{1'b0}}
) (
    // inputs to PLL
    input   wire                    clk_in,         // 200 MHz input
    input   wire                    rst_in,

    // pixel clock output (all outputs are synchronous to this)
    output  wire                    clk_px,
    output  wire                    rst_px,         // rst for clk_px domain

    // status
    output  reg                     rdy,            // data should be valid

    // deserialized pixels
    output  wire    [(WIDTH*10)-1:0] px,
    output  wire    [WIDTH-1:0]     line_valid,
    output  wire    [WIDTH-1:0]     frame_valid,
    output  wire    [WIDTH-1:0]     train_done,
    output  wire    [(WIDTH*8)-1:0] iod_cnt,
    output  wire    [(WIDTH*8)-1:0] skew_cnt,

    // LVDS data inputs from image sensors
    input   wire    [WIDTH-1:0]     in_p,           // connect to top-level port
    input   wire    [WIDTH-1:0]     in_n,           // connect to top-level port

    // single-ended clock outputs to image sensors
    output  wire    [WIDTH-1:0]     clk_out         // connect to top-level port
);

// Clocks
wire rst;            // synchronous to clk
wire rst_2x;         // synchronous to clk_2x
wire rst_9x;         // synchronous to clk_9x
wire clk;            // pixel clock
wire clk_2x;         // clk * 2
wire clk_9x;         // clk * 9
wire clk_12x;        // clk * 12
wire clk_36x;        // clk * 36
wire strobe_12to2;   // serdes_strobe for clk_12x -> clk_2x
wire strobe_36to9;   // serdes_strobe for clk_36x -> clk_9x

assign clk_px = clk;
assign rst_px = rst;

mt9v032_clocks mt9v032_clocks_inst (
    .clk_in         ( clk_in ),
    .rst_in         ( rst_in ),
    .rst            ( rst ),
    .rst_2x         ( rst_2x ),
    .rst_9x         ( rst_9x ),
    .clk            ( clk ),
    .clk_2x         ( clk_2x ),
    .clk_9x         ( clk_9x ),
    .clk_12x        ( clk_12x ),
    .clk_36x        ( clk_36x ),
    .strobe_12to2   ( strobe_12to2 ),
    .strobe_36to9   ( strobe_36to9 )
);


// ISERDES phase-detector control
wire    [WIDTH-1:0] iod_busy;
wire                iod_rst;
wire                iod_mask;
wire                iod_cal;
wire                iod_cal_master;
wire                iod_ready;

iserdes_control #(
    .WIDTH  ( WIDTH )
) iserdes_control_inst (
    .clk_div        ( clk_2x ),
    .rst            ( rst_2x ),
    .ready          ( iod_ready ),
    .iod_busy       ( iod_busy ),
    .iod_rst        ( iod_rst ),
    .iod_mask       ( iod_mask ),
    .iod_cal        ( iod_cal ),
    .iod_cal_master ( iod_cal_master )
);

// Camera SerDes
genvar j;
generate
    for(j=0;j<WIDTH;j=j+1) begin:GEN_CAMERA_SERDES
        wire [9:0] data;

        mt9v032_serdes #(
            .SWAP   ( SWAP & (1<<j) )
        ) mt9v032_serdes_inst (
            .rst_2x         ( rst_2x ),
            .rst_9x         ( rst_9x ),
            .clk            ( clk ),
            .clk_2x         ( clk_2x ),
            .clk_9x         ( clk_9x ),
            .clk_12x        ( clk_12x ),
            .clk_36x        ( clk_36x ),
            .strobe_12to2   ( strobe_12to2 ),
            .strobe_36to9   ( strobe_36to9 ),
            .data           ( data ),
            .train_done     ( train_done[j] ),
            .iod_cnt        ( iod_cnt[ j*8 +: 8 ] ),
            .skew_cnt       ( skew_cnt[ j*8 +: 8 ] ),
            .inhibit_skew   ( frame_valid[j] ),
            .in_p           ( in_p[j] ),
            .in_n           ( in_n[j] ),
            .clk_out        ( clk_out[j] ),
            .iod_rst        ( iod_rst ),
            .iod_mask       ( iod_mask ),
            .iod_cal        ( iod_cal ),
            .iod_cal_master ( iod_cal_master ),
            .iod_busy       ( iod_busy[j] )
        );

        mt9v032_post mt9v032_post_inst (
            .rst            ( !train_done[j] ),
            .clk            ( clk ),
            .data_in        ( data ),
            .px             ( px[ j*10 +: 10 ] ),
            .line_valid     ( line_valid[j] ),
            .frame_valid    ( frame_valid[j] )
        );
    end
endgenerate

// generate rdy signal
reg [11:0] rdy_cnt;
always @(posedge clk) begin
    if(rst) begin
        rdy     <= 1'b0;
        rdy_cnt <= 0;
    end else begin
        rdy     <= 1'b0;
        if(&train_done && iod_ready) begin
            if(&rdy_cnt) begin
                rdy     <= 1'b1;
            end else begin
                rdy_cnt <= rdy_cnt + 1;
            end
        end else begin
            rdy_cnt <= 0;
        end
    end
end

endmodule

