
module dlsc_uart_tx_core_test #(
    parameter START         = 1,
    parameter STOP          = 1,
    parameter DATA          = 8,
    parameter PARITY        = 0,
    parameter OVERSAMPLE    = 16,
    parameter FREQ_IN       = 100000000,
    parameter FREQ_OUT      = 115200
) (
    // system
    input   wire                clk,
    input   wire                rst,

    // uart pins
    output  wire                tx,
    output  wire                tx_en,

    // transmit data
    output  wire                ready,
    input   wire                valid,
    input   wire    [DATA-1:0]  data
);

wire clk_en;

dlsc_uart_tx_core #(
    .START          ( START ),
    .STOP           ( STOP ),
    .DATA           ( DATA ),
    .PARITY         ( PARITY ),
    .OVERSAMPLE     ( OVERSAMPLE )
) dlsc_uart_tx_core_inst (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .rst            ( rst ),
    .tx             ( tx ),
    .tx_en          ( tx_en ),
    .ready          ( ready ),
    .valid          ( valid ),
    .data           ( data )
);

dlsc_clocksynth #(
    .FREQ_IN        ( FREQ_IN ),
    .FREQ_OUT       ( FREQ_OUT*OVERSAMPLE )
) dlsc_clocksynth_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .clk_en_out     ( clk_en )
);


endmodule

