
module dlsc_sp605_clocks #(
    parameter IN_DIV    = 5,
    parameter IN_MULT   = 24,
    parameter CLK_DIV   = 12,
    parameter PX_DIV    = 40
) (
    input   wire                    clk200_in,
    input   wire                    rst_in,

    output  wire                    clk,    // 80 MHz
    output  wire                    rst,

    output  wire                    px_clk, // 24 MHz
    output  wire                    px_rst
);

wire    locked;

dlsc_rstsync #(
    .DOMAINS    ( 2 )
) dlsc_rstsync_inst (
    .rst_in     ( !locked ),
    .clk        ( { px_clk, clk } ),
    .rst_out    ( { px_rst, rst } )
);

wire    clk_fb;

(* KEEP = "TRUE" *) wire clk0_pre;
(* KEEP = "TRUE" *) wire clk1_pre;

BUFG BUFG_clk (
    .I ( clk0_pre ),
    .O ( clk )
);

BUFG BUFG_px_clk (
    .I ( clk1_pre ),
    .O ( px_clk )
);

PLL_BASE #(
    .BANDWIDTH("OPTIMIZED"),                // "HIGH", "LOW" or "OPTIMIZED" 
    .CLKFBOUT_MULT( IN_MULT ),              // Multiply value for all CLKOUT clock outputs (1-64)
    .CLKFBOUT_PHASE(0.0),                   // Phase offset in degrees of the clock feedback output (0.0-360.0).
    .CLKIN_PERIOD(5.0),                     // Input clock period in ns to ps resolution (i.e. 33.333 is 30
                                            // MHz).
    // CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for CLKOUT# clock output (1-128)
    .CLKOUT0_DIVIDE( CLK_DIV ),
    .CLKOUT1_DIVIDE( PX_DIV ),
    .CLKOUT2_DIVIDE(1),
    .CLKOUT3_DIVIDE(1),
    .CLKOUT4_DIVIDE(1),
    .CLKOUT5_DIVIDE(1),
    // CLKOUT0_DUTY_CYCLE - CLKOUT5_DUTY_CYCLE: Duty cycle for CLKOUT# clock output (0.01-0.99).
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT1_DUTY_CYCLE(0.5),
    .CLKOUT2_DUTY_CYCLE(0.5),
    .CLKOUT3_DUTY_CYCLE(0.5),
    .CLKOUT4_DUTY_CYCLE(0.5),
    .CLKOUT5_DUTY_CYCLE(0.5),
    // CLKOUT0_PHASE - CLKOUT5_PHASE: Output phase relationship for CLKOUT# clock output (-360.0-360.0).
    .CLKOUT0_PHASE(0.0),
    .CLKOUT1_PHASE(0.0),
    .CLKOUT2_PHASE(0.0),
    .CLKOUT3_PHASE(0.0),
    .CLKOUT4_PHASE(0.0),
    .CLKOUT5_PHASE(0.0),
    .CLK_FEEDBACK("CLKFBOUT"),              // Clock source to drive CLKFBIN ("CLKFBOUT" or "CLKOUT0")
    .COMPENSATION("SYSTEM_SYNCHRONOUS"),    // "SYSTEM_SYNCHRONOUS", "SOURCE_SYNCHRONOUS", "EXTERNAL" 
    .DIVCLK_DIVIDE( IN_DIV ),               // Division value for all output clocks (1-52)
    .REF_JITTER(0.1),                       // Reference Clock Jitter in UI (0.000-0.999).
    .RESET_ON_LOSS_OF_LOCK("FALSE")         // Must be set to FALSE
)
PLL_BASE_inst (
    .CLKFBOUT       ( clk_fb ),             // 1-bit output: PLL_BASE feedback output
    // CLKOUT0 - CLKOUT5: 1-bit (each) output: Clock outputs
    .CLKOUT0        ( clk0_pre ),
    .CLKOUT1        ( clk1_pre ),
    .CLKOUT2        ( clk2_pre ),
    .CLKOUT3        ( clk3_pre ),
    .CLKOUT4        ( clk4_pre ),
    .CLKOUT5        ( clk5_pre ),
    .LOCKED         ( locked ),             // 1-bit output: PLL_BASE lock status output
    .CLKFBIN        ( clk_fb ),             // 1-bit input: Feedback clock input
    .CLKIN          ( clk200_in ),          // 1-bit input: Clock input
    .RST            ( rst_in )              // 1-bit input: Reset input
);

endmodule

