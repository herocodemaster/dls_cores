module dlsc_stereobm_pipe_adder_slice #(
    parameter DATA          = 16,
    parameter SUM_BITS      = DATA+4,
    parameter DELAY         = 2
) (
    input   wire                            clk,

    input   wire    [DATA-1:0]              in_sub,
    input   wire    [DATA-1:0]              in_add,

    input   wire    [SUM_BITS-1:0]          in_data,    // should be valid DELAY cycles after in_sub/add

    output  wire    [SUM_BITS-1:0]          out_data
);

`include "dlsc_synthesis.vh"

localparam PAD = SUM_BITS-(DATA+1);

`DLSC_NO_SHREG reg [DATA:0] c1_data;
always @(posedge clk)
    c1_data <= {1'b0,in_add} - {1'b0,in_sub};

wire [DATA:0] cn_data;

dlsc_pipedelay #(
    .DATA   ( DATA+1 ),
    .DELAY  ( DELAY-1 )
) dlsc_pipedelay_inst (
    .clk        ( clk ),
    .in_data    ( c1_data ),
    .out_data   ( cn_data )
);

`DLSC_NO_SHREG reg [SUM_BITS-1:0] out_data_r;
assign out_data = out_data_r;

always @(posedge clk)
    out_data_r <= in_data + { {PAD{cn_data[DATA]}} , cn_data };

endmodule

