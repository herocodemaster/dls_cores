
module mt9v032_clocks (
    // inputs to PLL
    input   wire                    clk_in,         // 200 MHz input
    input   wire                    rst_in,
    
    // outputs to mt9v032_serdes instances
    output  wire                    rst,            // synchronous to clk
    output  wire                    rst_2x,         // synchronous to clk_2x
    output  wire                    rst_9x,         // synchronous to clk_9x
    output  wire                    clk,            // pixel clock
    output  wire                    clk_2x,         // clk * 2
    output  wire                    clk_9x,         // clk * 9
    output  wire                    clk_12x,        // clk * 12
    output  wire                    clk_36x,        // clk * 36
    output  wire                    strobe_12to2,   // serdes_strobe for clk_12x -> clk_2x
    output  wire                    strobe_36to9    // serdes_strobe for clk_36x -> clk_9x
);

// main PLL
wire pll_fb;
wire pll_locked;
wire clk_pre;
wire clk_2x_pre;
wire clk_9x_pre;
wire clk_12x_pre;
wire clk_36x_pre;
PLL_BASE #(
    .BANDWIDTH              ( "OPTIMIZED" ),            // "HIGH", "LOW" or "OPTIMIZED" 
    .CLKFBOUT_MULT          ( 24 ),                     // Multiply value for all CLKOUT clock outputs (1-64)
    .CLKFBOUT_PHASE         ( 0.0 ),                    // Phase offset in degrees of the clock feedback output (0.0-360.0).
    .CLKIN_PERIOD           ( 5.0 ),                    // Input clock period in ns to ps resolution (i.e. 33.333 is 30
                                                        // MHz).
    // CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for CLKOUT# clock output (1-128)
    .CLKOUT0_DIVIDE         ( 1 ),  // clk_36x
    .CLKOUT1_DIVIDE         ( 3 ),  // clk_12x
    .CLKOUT2_DIVIDE         ( 4 ),  // clk_9x
    .CLKOUT3_DIVIDE         ( 18 ), // clk_2x
    .CLKOUT4_DIVIDE         ( 36 ), // clk
    .CLKOUT5_DIVIDE         ( 1 ),
    // CLKOUT0_DUTY_CYCLE - CLKOUT5_DUTY_CYCLE: Duty cycle for CLKOUT# clock output (0.01-0.99).
    .CLKOUT0_DUTY_CYCLE     ( 0.5 ),
    .CLKOUT1_DUTY_CYCLE     ( 0.5 ),
    .CLKOUT2_DUTY_CYCLE     ( 0.5 ),
    .CLKOUT3_DUTY_CYCLE     ( 0.5 ),
    .CLKOUT4_DUTY_CYCLE     ( 0.5 ),
    .CLKOUT5_DUTY_CYCLE     ( 0.5 ),
    // CLKOUT0_PHASE - CLKOUT5_PHASE: Output phase relationship for CLKOUT# clock output (-360.0-360.0).
    .CLKOUT0_PHASE          ( 0.0 ),
    .CLKOUT1_PHASE          ( 0.0 ),
    .CLKOUT2_PHASE          ( 0.0 ),
    .CLKOUT3_PHASE          ( 0.0 ),
    .CLKOUT4_PHASE          ( 0.0 ),
    .CLKOUT5_PHASE          ( 0.0 ),
    .CLK_FEEDBACK           ( "CLKFBOUT" ),             // Clock source to drive CLKFBIN ("CLKFBOUT" or "CLKOUT0")
    .COMPENSATION           ( "SYSTEM_SYNCHRONOUS" ),   // "SYSTEM_SYNCHRONOUS", "SOURCE_SYNCHRONOUS", "EXTERNAL" 
    .DIVCLK_DIVIDE          ( 5 ),                      // Division value for all output clocks (1-52)
    .REF_JITTER             ( 0.1 ),                    // Reference Clock Jitter in UI (0.000-0.999).
    .RESET_ON_LOSS_OF_LOCK  ( "FALSE" )                 // Must be set to FALSE
) PLL_BASE_inst (
    .CLKFBOUT               ( pll_fb ), // 1-bit PLL_BASE feedback output
    // CLKOUT0 - CLKOUT5: 1-bit (each) Clock outputs
    .CLKOUT0                ( clk_36x_pre ),
    .CLKOUT1                ( clk_12x_pre ),
    .CLKOUT2                ( clk_9x_pre ),
    .CLKOUT3                ( clk_2x_pre ),
    .CLKOUT4                ( clk_pre ),
    .CLKOUT5                (  ),
    .LOCKED                 ( pll_locked ),             // 1-bit PLL_BASE lock status output
    .CLKFBIN                ( pll_fb ),                 // 1-bit Feedback clock input
    .CLKIN                  ( clk_in ),                 // 1-bit Clock input
    .RST                    ( rst_in )                  // 1-bit Reset input
);

// clock buffers
BUFG BUFG_clk_inst (
    .O  ( clk ),        // 1-bit Clock buffer output
    .I  ( clk_pre )     // 1-bit Clock buffer input
);

BUFG BUFG_clk_2x_inst (
    .O  ( clk_2x ),     // 1-bit Clock buffer output
    .I  ( clk_2x_pre )  // 1-bit Clock buffer input
);

BUFG BUFG_clk_9x_inst (
    .O  ( clk_9x ),     // 1-bit Clock buffer output
    .I  ( clk_9x_pre )  // 1-bit Clock buffer input
);

// BUFPLL for 12x/2x
wire locked_12to2;
BUFPLL #(
    .DIVIDE         ( 6 ),              // DIVCLK divider (1-8)
    .ENABLE_SYNC    ( "TRUE" )          // Enable synchrnonization between PLL and GCLK (TRUE/FALSE)
)
BUFPLL_12to2_inst (
    .PLLIN          ( clk_12x_pre ),    // 1-bit Clock input from PLL
    .GCLK           ( clk_2x ),         // 1-bit BUFG clock input
    .LOCKED         ( pll_locked ),     // 1-bit LOCKED input from PLL
    
    .IOCLK          ( clk_12x ),        // 1-bit Output I/O clock
    .SERDESSTROBE   ( strobe_12to2 ),   // 1-bit Output SERDES strobe (connect to ISERDES2/OSERDES2)
    
    .LOCK           ( locked_12to2 )    // 1-bit Synchronized LOCK output
);

// BUFPLL for 36x/9x
wire locked_36to9;
BUFPLL #(
    .DIVIDE         ( 4 ),              // DIVCLK divider (1-8)
    .ENABLE_SYNC    ( "TRUE" )          // Enable synchrnonization between PLL and GCLK (TRUE/FALSE)
)
BUFPLL_36to9_inst (
    .PLLIN          ( clk_36x_pre ),    // 1-bit Clock input from PLL
    .GCLK           ( clk_9x ),         // 1-bit BUFG clock input
    .LOCKED         ( pll_locked ),     // 1-bit LOCKED input from PLL
    
    .IOCLK          ( clk_36x ),        // 1-bit Output I/O clock
    .SERDESSTROBE   ( strobe_36to9 ),   // 1-bit Output SERDES strobe (connect to ISERDES2/OSERDES2)
    
    .LOCK           ( locked_36to9 )    // 1-bit Synchronized LOCK output
);

wire rst_pre = !( pll_locked && locked_12to2 && locked_36to9 );

dlsc_rstsync dlsc_rstsync_1x (
    .clk        ( clk ),
    .rst_in     ( rst_pre ),
    .rst_out    ( rst )
);

dlsc_rstsync dlsc_rstsync_2x (
    .clk        ( clk_2x ),
    .rst_in     ( rst_pre ),
    .rst_out    ( rst_2x )
);

dlsc_rstsync dlsc_rstsync_9x (
    .clk        ( clk_9x ),
    .rst_in     ( rst_pre ),
    .rst_out    ( rst_9x )
);


endmodule

