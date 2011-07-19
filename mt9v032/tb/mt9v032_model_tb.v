`timescale 1ns/1ps

module mt9v032_model_tb;


reg clk = 0;
initial forever
    #20.0 clk = !clk;

reg train;

wire out_p;
wire out_n;

wire clk_del;
real delay = 0.0;

assign #delay clk_del = clk;

mt9v032_model mt9v032_model_inst (
    .clk    ( clk_del ),
    .train  ( train ),
    .out_p  ( out_p ),
    .out_n  ( out_n )
);

initial begin

    train = 1;

    repeat(200) @(posedge clk)
        delay = delay + 0.1;

    #5000;

    train = 0;

    #5000;

    $finish;

end


endmodule

