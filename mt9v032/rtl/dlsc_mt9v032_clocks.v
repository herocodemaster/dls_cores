
module dlsc_mt9v032_clocks (
    // inputs to PLL
    input   wire                    clk_in,         // 200 MHz input
    input   wire                    rst_in,
    
    // outputs to mt9v032 instances
    // iserdes
    output  wire                    is_rst,         // synchronous to clk
    output  wire                    is_clk,         // px_clk * 2
    output  wire                    is_clk_fast,    // px_clk * 12
    output  wire                    is_strobe,      // serdes_strobe for is_clk_fast -> clk
    output  wire                    is_clk_en,      // half-rate enable (turns is_clk into px_clk)
    // oserdes
    output  wire                    os_rst,         // synchronous to os_clk
    output  wire                    os_clk,         // px_clk * 9
    output  wire                    os_clk_fast,    // px_clk * 36
    output  wire                    os_strobe       // serdes_strobe for os_clk_fast -> os_clk
);

`include "dlsc_synthesis.vh"

// main PLL
wire pll_fb;
wire pll_locked;
wire clk_pre;
wire os_clk_pre;
wire is_clk_fast_pre;
wire os_clk_fast_pre;
PLL_BASE #(
    .BANDWIDTH              ( "OPTIMIZED" ),            // "HIGH", "LOW" or "OPTIMIZED" 
    .CLKFBOUT_MULT          ( 24 ),                     // Multiply value for all CLKOUT clock outputs (1-64)
    .CLKFBOUT_PHASE         ( 0.0 ),                    // Phase offset in degrees of the clock feedback output (0.0-360.0).
    .CLKIN_PERIOD           ( 5.0 ),                    // Input clock period in ns to ps resolution (i.e. 33.333 is 30
                                                        // MHz).
    // CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for CLKOUT# clock output (1-128)
    .CLKOUT0_DIVIDE         ( 1 ),  // os_clk_fast
    .CLKOUT1_DIVIDE         ( 3 ),  // is_clk_fast
    .CLKOUT2_DIVIDE         ( 4 ),  // os_clk
    .CLKOUT3_DIVIDE         ( 18 ), // clk
    .CLKOUT4_DIVIDE         ( 1 ),
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
    .CLKFBOUT               ( pll_fb ),                 // 1-bit PLL_BASE feedback output
    // CLKOUT0 - CLKOUT5: 1-bit (each) Clock outputs
    .CLKOUT0                ( os_clk_fast_pre ),
    .CLKOUT1                ( is_clk_fast_pre ),
    .CLKOUT2                ( os_clk_pre ),
    .CLKOUT3                ( clk_pre ),
    .CLKOUT4                (  ),
    .CLKOUT5                (  ),
    .LOCKED                 ( pll_locked ),             // 1-bit PLL_BASE lock status output
    .CLKFBIN                ( pll_fb ),                 // 1-bit Feedback clock input
    .CLKIN                  ( clk_in ),                 // 1-bit Clock input
    .RST                    ( rst_in )                  // 1-bit Reset input
);

// clock buffers
BUFG BUFG_clk (
    .O  ( is_clk ),     // 1-bit Clock buffer output
    .I  ( clk_pre )     // 1-bit Clock buffer input
);

BUFG BUFG_os_clk (
    .O  ( os_clk ),     // 1-bit Clock buffer output
    .I  ( os_clk_pre )  // 1-bit Clock buffer input
);

// BUFPLL for ISERDES
wire locked_is;
BUFPLL #(
    .DIVIDE         ( 6 ),              // DIVCLK divider (1-8)
    .ENABLE_SYNC    ( "TRUE" )          // Enable synchrnonization between PLL and GCLK (TRUE/FALSE)
) BUFPLL_is (
    .PLLIN          ( is_clk_fast_pre ),// 1-bit Clock input from PLL
    .GCLK           ( is_clk ),         // 1-bit BUFG clock input
    .LOCKED         ( pll_locked ),     // 1-bit LOCKED input from PLL
    
    .IOCLK          ( is_clk_fast ),    // 1-bit Output I/O clock
    .SERDESSTROBE   ( is_strobe ),      // 1-bit Output SERDES strobe (connect to ISERDES2/OSERDES2)
    
    .LOCK           ( locked_is )       // 1-bit Synchronized LOCK output
);

// BUFPLL for OSERDES
wire locked_os;
BUFPLL #(
    .DIVIDE         ( 4 ),              // DIVCLK divider (1-8)
    .ENABLE_SYNC    ( "TRUE" )          // Enable synchrnonization between PLL and GCLK (TRUE/FALSE)
) BUFPLL_os (
    .PLLIN          ( os_clk_fast_pre ),// 1-bit Clock input from PLL
    .GCLK           ( os_clk ),         // 1-bit BUFG clock input
    .LOCKED         ( pll_locked ),     // 1-bit LOCKED input from PLL
    
    .IOCLK          ( os_clk_fast ),    // 1-bit Output I/O clock
    .SERDESSTROBE   ( os_strobe ),      // 1-bit Output SERDES strobe (connect to ISERDES2/OSERDES2)
    
    .LOCK           ( locked_os )       // 1-bit Synchronized LOCK output
);

wire rst_pre = !( pll_locked && locked_is && locked_os );

dlsc_rstsync #(
    .DOMAINS    ( 2 )
) dlsc_rstsync_inst (
    .rst_in     ( rst_pre ),
    .clk        ( { os_clk, is_clk } ),
    .rst_out    ( { os_rst, is_rst } )
);

// clock enable for px_clk

`DLSC_FANOUT_REG reg is_clk_en_r;
assign is_clk_en = is_clk_en_r;

always @(posedge is_clk) begin
    if(is_rst) begin
        is_clk_en_r <= 1'b0;
    end else begin
        is_clk_en_r <= !is_clk_en_r;
    end
end


endmodule

