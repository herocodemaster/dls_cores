
module dlsc_uart_rx_core_test #(
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
    input   wire                rx,
    input   wire                rx_mask,        // disable reception when asserted

    // received data
    output  wire                valid,          // qualifier; asserts for just 1 cycle
    output  wire    [DATA-1:0]  data,           // received data
    output  wire                frame_error,    // start/stop bits incorrect
    output  wire                parity_error    // parity check failed
);

wire clk_en;

dlsc_uart_rx_core #(
    .START          ( START ),
    .STOP           ( STOP ),
    .DATA           ( DATA ),
    .PARITY         ( PARITY ),
    .OVERSAMPLE     ( OVERSAMPLE )
) dlsc_uart_rx_core_inst (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .rst            ( rst ),
    .rx             ( rx ),
    .rx_mask        ( rx_mask ),
    .valid          ( valid ),
    .data           ( data ),
    .frame_error    ( frame_error ),
    .parity_error   ( parity_error )
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

