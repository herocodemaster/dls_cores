
module dlsc_sp605_ch7301c #(
    parameter DELAY_CLK     = 48,       // 48 yields delay of 0.53-2.54ns (across all devices and operating conditions)
    parameter DELAY_DATA    = 0
) (
    // Input
    input   wire                    px_clk,
    input   wire                    px_clk_n,
    input   wire                    px_en,
    input   wire                    px_vsync,
    input   wire                    px_hsync,
    input   wire                    px_valid,
    input   wire    [7:0]           px_r,
    input   wire    [7:0]           px_g,
    input   wire    [7:0]           px_b,

    // Output (to top-level ports)
    output  wire                    out_clk_p,
    output  wire                    out_clk_n,
    output  wire    [11:0]          out_data,
    output  wire                    out_de,
    output  wire                    out_hsync_n,
    output  wire                    out_vsync_n
);

// ** clock **

wire r_clk;
wire r_clk_dly;

// register

ODDR2 #(
    .DDR_ALIGNMENT      ( "C0" ),           // Sets output alignment to "NONE", "C0" or "C1" 
    .INIT               ( 1'b0 ),           // Sets initial state of the Q output to 1'b0 or 1'b1
    .SRTYPE             ( "ASYNC" )         // Specifies "SYNC" or "ASYNC" set/reset
) ODDR2_clk (
    .Q                  ( r_clk ),          // 1-bit DDR output data
    .C0                 ( px_clk ),         // 1-bit clock input
    .C1                 ( px_clk_n ),       // 1-bit clock input
    .CE                 ( 1'b1 ),           // 1-bit clock enable input
    .D0                 ( 1'b1 ),           // 1-bit data input (associated with C0)
    .D1                 ( 1'b0 ),           // 1-bit data input (associated with C1)
    .R                  ( !px_en ),         // 1-bit reset input
    .S                  ( 1'b0 )            // 1-bit set input
);

// delay

IODELAY2 #(
    .COUNTER_WRAPAROUND ( "WRAPAROUND" ),   // "STAY_AT_LIMIT" or "WRAPAROUND" 
    .DATA_RATE          ( "DDR" ),          // "SDR" or "DDR" 
    .DELAY_SRC          ( "ODATAIN" ),      // "IO", "ODATAIN" or "IDATAIN" 
    .IDELAY2_VALUE      ( 0 ),              // Delay value when IDELAY_MODE="PCI" (0-255)
    .IDELAY_MODE        ( "NORMAL" ),       // "NORMAL" or "PCI" 
    .IDELAY_TYPE        ( "FIXED" ),        // "FIXED", "DEFAULT", "VARIABLE_FROM_ZERO", "VARIABLE_FROM_HALF_MAX" 
                                            // or "DIFF_PHASE_DETECTOR" 
    .IDELAY_VALUE       ( 0 ),              // Amount of taps for fixed input delay (0-255)
    .ODELAY_VALUE       ( DELAY_CLK ),      // Amount of taps fixed output delay (0-255)
    .SERDES_MODE        ( "NONE" ),         // "NONE", "MASTER" or "SLAVE" 
    .SIM_TAPDELAY_VALUE ( 75 )              // Per tap delay used for simulation in ps
)
IODELAY2_clk (
    .BUSY               (  ),               // 1-bit output: Busy output after CAL
    .DATAOUT            (  ),               // 1-bit output: Delayed data output to ISERDES/input register
    .DATAOUT2           (  ),               // 1-bit output: Delayed data output to general FPGA fabric
    .DOUT               ( r_clk_dly ),      // 1-bit output: Delayed data output
    .TOUT               (  ),               // 1-bit output: Delayed 3-state output
    .CAL                ( 1'b0 ),           // 1-bit input: Initiate calibration input
    .CE                 ( 1'b0 ),           // 1-bit input: Enable INC input
    .CLK                ( 1'b0 ),           // 1-bit input: Clock input
    .IDATAIN            ( 1'b0 ),           // 1-bit input: Data input (connect to top-level port or I/O buffer)
    .INC                ( 1'b0 ),           // 1-bit input: Increment / decrement input
    .IOCLK0             ( 1'b0 ),           // 1-bit input: Input from the I/O clock network
    .IOCLK1             ( 1'b0 ),           // 1-bit input: Input from the I/O clock network
    .ODATAIN            ( r_clk ),          // 1-bit input: Output data input from output register or OSERDES2.
    .RST                ( 1'b0 ),           // 1-bit input: Reset to zero or 1/2 of total delay period
    .T                  ( 1'b0 )            // 1-bit input: 3-state input signal
);

// pad

OBUFDS #(
    .IOSTANDARD         ( "DIFF_SSTL2_I" )  // Specify the output I/O standard
) OBUFDS_clk (
    .O                  ( out_clk_p ),      // Diff_p output (connect directly to top-level port)
    .OB                 ( out_clk_n ),      // Diff_n output (connect directly to top-level port)
    .I                  ( r_clk_dly )       // Buffer input 
);

// ** data/control **

wire [14:0] data_a; // rising edge
wire [14:0] data_b; // falling edge

assign data_a[7:0]  = px_b[7:0];
assign data_a[11:8] = px_g[3:0];
assign data_b[3:0]  = px_g[7:4];
assign data_b[11:4] = px_r[7:0];

assign data_a[14:12]= { !px_vsync, !px_hsync, px_valid };
assign data_b[14:12]= data_a[14:12];

wire [14:0] r_data;
wire [14:0] r_data_dly;
wire [14:0] r_data_pad;

assign out_data     = r_data_pad[11:0];
assign out_de       = r_data_pad[12];
assign out_hsync_n  = r_data_pad[13];
assign out_vsync_n  = r_data_pad[14];

genvar j;
generate
for(j=0;j<15;j=j+1) begin:GEN_DATA

    // register

    ODDR2 #(
        .DDR_ALIGNMENT      ( "C0" ),           // Sets output alignment to "NONE", "C0" or "C1" 
        .INIT               ( 1'b0 ),           // Sets initial state of the Q output to 1'b0 or 1'b1
        .SRTYPE             ( "ASYNC" )         // Specifies "SYNC" or "ASYNC" set/reset
    ) ODDR2_data (
        .Q                  ( r_data[j] ),      // 1-bit DDR output data
        .C0                 ( px_clk ),         // 1-bit clock input
        .C1                 ( px_clk_n ),       // 1-bit clock input
        .CE                 ( 1'b1 ),           // 1-bit clock enable input
        .D0                 ( data_a[j] ),      // 1-bit data input (associated with C0)
        .D1                 ( data_b[j] ),      // 1-bit data input (associated with C1)
        .R                  ( !px_en ),         // 1-bit reset input
        .S                  ( 1'b0 )            // 1-bit set input
    );

    // delay

    IODELAY2 #(
        .COUNTER_WRAPAROUND ( "WRAPAROUND" ),   // "STAY_AT_LIMIT" or "WRAPAROUND" 
        .DATA_RATE          ( "DDR" ),          // "SDR" or "DDR" 
        .DELAY_SRC          ( "ODATAIN" ),      // "IO", "ODATAIN" or "IDATAIN" 
        .IDELAY2_VALUE      ( 0 ),              // Delay value when IDELAY_MODE="PCI" (0-255)
        .IDELAY_MODE        ( "NORMAL" ),       // "NORMAL" or "PCI" 
        .IDELAY_TYPE        ( "FIXED" ),        // "FIXED", "DEFAULT", "VARIABLE_FROM_ZERO", "VARIABLE_FROM_HALF_MAX" 
                                                // or "DIFF_PHASE_DETECTOR" 
        .IDELAY_VALUE       ( 0 ),              // Amount of taps for fixed input delay (0-255)
        .ODELAY_VALUE       ( DELAY_DATA ),     // Amount of taps fixed output delay (0-255)
        .SERDES_MODE        ( "NONE" ),         // "NONE", "MASTER" or "SLAVE" 
        .SIM_TAPDELAY_VALUE ( 75 )              // Per tap delay used for simulation in ps
    )
    IODELAY2_data (
        .BUSY               (  ),               // 1-bit output: Busy output after CAL
        .DATAOUT            (  ),               // 1-bit output: Delayed data output to ISERDES/input register
        .DATAOUT2           (  ),               // 1-bit output: Delayed data output to general FPGA fabric
        .DOUT               ( r_data_dly[j] ),  // 1-bit output: Delayed data output
        .TOUT               (  ),               // 1-bit output: Delayed 3-state output
        .CAL                ( 1'b0 ),           // 1-bit input: Initiate calibration input
        .CE                 ( 1'b0 ),           // 1-bit input: Enable INC input
        .CLK                ( 1'b0 ),           // 1-bit input: Clock input
        .IDATAIN            ( 1'b0 ),           // 1-bit input: Data input (connect to top-level port or I/O buffer)
        .INC                ( 1'b0 ),           // 1-bit input: Increment / decrement input
        .IOCLK0             ( 1'b0 ),           // 1-bit input: Input from the I/O clock network
        .IOCLK1             ( 1'b0 ),           // 1-bit input: Input from the I/O clock network
        .ODATAIN            ( r_data[j] ),      // 1-bit input: Output data input from output register or OSERDES2.
        .RST                ( 1'b0 ),           // 1-bit input: Reset to zero or 1/2 of total delay period
        .T                  ( 1'b0 )            // 1-bit input: 3-state input signal
    );

    // pad

    OBUF #(
        .DRIVE              ( 12 ),             // Specify the output drive strength
        .IOSTANDARD         ( "SSTL2_I" ),      // Specify the output I/O standard
        .SLEW               ( "FAST" )          // Specify the output slew rate
    ) OBUF_data (
        .O                  ( r_data_pad[j] ),  // Buffer output (connect directly to top-level port)
        .I                  ( r_data_dly[j] )   // Buffer input 
    );

end
endgenerate

endmodule

