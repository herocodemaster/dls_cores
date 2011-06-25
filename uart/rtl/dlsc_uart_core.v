
module dlsc_uart_core #(
    parameter START         = 1,
    parameter STOP          = 1,
    parameter DATA          = 8,
    parameter PARITY        = 0,
    parameter CLKFREQ       = 100000000,
    parameter BAUD          = 115200,
    parameter FIFO_DEPTH    = 1,
    parameter OVERSAMPLE    = 16
) (
    // system
    input   wire                clk,
    input   wire                rst,

    // uart pins
    output  wire                tx,
    input   wire                rx,

    // uart enables (for half-duplex operation)
    output  wire                tx_en,
    input   wire                rx_mask,

    // transmit FIFO
    input   wire                tx_push,
    input   wire    [DATA-1:0]  tx_data,
    output  wire                tx_full,

    // receive FIFO
    input   wire                rx_pop,
    output  wire    [DATA-1:0]  rx_data,
    output  wire                rx_empty,

    // receive error flags
    input   wire                error_clear,
    output  reg                 error_frame,
    output  reg                 error_parity
);


// ** baud clock generator

wire clk_en;

dlsc_clocksynth #(
    .FREQ_IN        ( CLKFREQ ),
    .FREQ_OUT       ( BAUD*OVERSAMPLE )
) dlsc_clocksynth_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .clk_en_out     ( clk_en )
);


// ** transmitter

wire            txi_ready;
wire            txi_valid;
wire [DATA-1:0] txi_data;

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
    .ready          ( txi_ready ),
    .valid          ( txi_valid ),
    .data           ( txi_data )
);


// ** receiver

wire            rxi_valid;
wire [DATA-1:0] rxi_data;
wire            rxi_frame_error;
wire            rxi_parity_error;

dlsc_uart_rx_core #(
    .START          ( START ),
    .STOP           ( 1 ),          // not much point in having more than 1
    .DATA           ( DATA ),
    .PARITY         ( PARITY ),
    .OVERSAMPLE     ( OVERSAMPLE )
) dlsc_uart_rx_core_inst (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .rst            ( rst ),
    .rx             ( rx ),
    .rx_mask        ( rx_mask ),
    .valid          ( rxi_valid ),
    .data           ( rxi_data ),
    .frame_error    ( rxi_frame_error ),
    .parity_error   ( rxi_parity_error )
);


// ** flag control

always @(posedge clk) begin
    if(rst) begin
        error_frame     <= 1'b0;
        error_parity    <= 1'b0;
    end else begin
        if(error_clear) begin
            // clear, but allow to be overriden below
            // (so flags aren't lost if cleared-on-read)
            error_frame     <= 1'b0;
            error_parity    <= 1'b0;
        end
        if(rxi_valid) begin
            if(rxi_frame_error) begin
                error_frame     <= 1'b1;
            end
            if(rxi_parity_error) begin
                error_parity    <= 1'b1;
            end
        end
    end
end


generate
    if(FIFO_DEPTH<=1) begin:GEN_NOFIFO

        // transmit

        assign txi_valid    = tx_push;
        assign txi_data     = tx_data;
        assign tx_full      = !txi_ready;

        // receive

        reg rx_empty_r;
        
        assign rx_data      = rxi_data;
        assign rx_empty     = rx_empty_r;

        always @(posedge clk) begin
            if(rst || rx_pop) begin
                rx_empty_r  <= 1'b1;
            end else if(rxi_valid) begin
                rx_empty_r  <= 1'b0;
            end
        end

        `ifdef DLSC_SIMULATION
        `include "dlsc_sim_top.vh"

        always @(posedge clk) begin
            if(tx_push && tx_full) begin
                `dlsc_error("tx overflow");
            end
            if(rx_pop && rx_empty) begin
                `dlsc_error("rx underflow");
            end
            if(rxi_valid && !rx_empty) begin
                `dlsc_error("rx overflow");
            end
        end

        `include "dlsc_sim_bot.vh"
        `endif

    end else begin:GEN_FIFOS

        // ** transmit buffer

        wire txi_empty;
        assign txi_valid = !txi_empty;

        dlsc_fifo_shiftreg #(
            .DATA           ( DATA ),
            .DEPTH          ( FIFO_DEPTH )
        ) dlsc_fifo_shiftreg_inst_tx (
            .clk            ( clk ),
            .rst            ( rst ),
            .push_en        ( tx_push ),
            .push_data      ( tx_data ),
            .full           ( tx_full ),
            .almost_full    (  ),
            .pop_en         ( txi_ready && txi_valid ),
            .pop_data       ( txi_data ),
            .empty          ( txi_empty ),
            .almost_empty   (  )
        );

        // ** receive buffer

        dlsc_fifo_shiftreg #(
            .DATA           ( DATA ),
            .DEPTH          ( FIFO_DEPTH )
        ) dlsc_fifo_shiftreg_inst_rx (
            .clk            ( clk ),
            .rst            ( rst ),
            .push_en        ( rxi_valid && !rxi_frame_error && !rxi_parity_error ),
            .push_data      ( rxi_data ),
            .full           (  ),
            .almost_full    (  ),
            .pop_en         ( rx_pop ),
            .pop_data       ( rx_data ),
            .empty          ( rx_empty ),
            .almost_empty   (  )
        );

    end

endgenerate


endmodule

