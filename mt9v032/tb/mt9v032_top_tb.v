`timescale 1ns/1ps

module mt9v032_top_tb;

`include "dlsc_tb_top.vh"

localparam WIDTH = `PARAM_WIDTH;

reg                 clk_in = 1'b0;
initial forever
    #2.5 clk_in = !clk_in;

reg                 rst_in = 1'b1;

wire                clk_px;
wire                rst_px;
wire                rdy;
wire    [WIDTH-1:0] line_valid;
wire    [WIDTH-1:0] frame_valid;
wire    [9:0]       data [WIDTH-1:0];
wire    [(WIDTH*10)-1:0] data_concat;
wire    [WIDTH-1:0] in_p;
wire    [WIDTH-1:0] in_n;
wire    [WIDTH-1:0] clk_out;
wire    [WIDTH-1:0] train_done;
wire    [(WIDTH*8)-1:0] iod_cnt;
wire    [(WIDTH*8)-1:0] skew_cnt;

mt9v032_top #(
    .WIDTH  ( WIDTH )
) mt9v032_top_inst (
    .clk_in     ( clk_in ),
    .rst_in     ( rst_in ),
    .clk_px     ( clk_px ),
    .rst_px     ( rst_px ),
    .rdy        ( rdy ),
    .px         ( data_concat ),
    .line_valid ( line_valid ),
    .frame_valid( frame_valid ),
    .train_done ( train_done ),
    .iod_cnt    ( iod_cnt ),
    .skew_cnt   ( skew_cnt ),
    .in_p       ( in_p ),
    .in_n       ( in_n ),
    .clk_out    ( clk_out )
);

reg                 train = 1'b0;

genvar j;
generate
    for(j=0;j<WIDTH;j=j+1) begin:GEN_MODELS
        mt9v032_model #(
            .CLK_DELAY  ( 100.0 + j * 300.0 )
        ) mt9v032_model_inst (
            .clk    ( clk_out[j] ),
            .train  ( train ),
            .out_p  ( in_p[j] ),
            .out_n  ( in_n[j] )
        );
        assign data[j] = data_concat[ (j*10)+9 : j*10 ];
    end
endgenerate


initial forever begin
    #10000
    `dlsc_info(".");
end


initial begin
    rst_in  = 1'b1;
    train   = 1'b1;
    #1000;
    @(posedge clk_in);
    rst_in  = 1'b0;

    `dlsc_info("deassert reset");

    @(posedge train_done[0]);

    `dlsc_info("got train_done");

    @(posedge rdy);

    `dlsc_info("got ready");

    train   = 1'b0;
    
    @(posedge frame_valid[0]);

    `dlsc_info("got frame_valid");

    @(negedge frame_valid[0]);

    `dlsc_info("got whole frame");

    `dlsc_okay("done");

    #1000;

    `dlsc_finish;
end

initial begin
    #1000000;
    `dlsc_error("watchdog timeout");

    `dlsc_finish;
end

endmodule

