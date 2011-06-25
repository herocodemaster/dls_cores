
module dlsc_domaincross_rvh_test #(
    parameter   DATA    = 32,
    parameter   RESET   = {DATA{1'b0}}
) (
    input   wire                rst,

    // source domain
    input   wire                in_clk,

    output  wire                in_ready,
    input   wire                in_valid,
    input   wire    [DATA-1:0]  in_data,

    // consumer domain
    input   wire                out_clk,

    input   wire                out_ready,
    output  wire                out_valid,
    output  wire    [DATA-1:0]  out_data
);

wire in_rst;
wire out_rst;

dlsc_rstsync dlsc_rstsync_in (
    .clk        ( in_clk ),
    .rst_in     ( rst ),
    .rst_out    ( in_rst )
);

dlsc_rstsync dlsc_rstsync_out (
    .clk        ( out_clk ),
    .rst_in     ( rst ),
    .rst_out    ( out_rst )
);

dlsc_domaincross_rvh #(
    .DATA       ( DATA ),
    .RESET      ( RESET )
) dlsc_domaincross_rvh_inst (
    .in_clk     ( in_clk ),
    .in_rst     ( in_rst ),
    .in_ready   ( in_ready ),
    .in_valid   ( in_valid ),
    .in_data    ( in_data ),
    .out_clk    ( out_clk ),
    .out_rst    ( out_rst ),
    .out_ready  ( out_ready ),
    .out_valid  ( out_valid ),
    .out_data   ( out_data )
);

endmodule

