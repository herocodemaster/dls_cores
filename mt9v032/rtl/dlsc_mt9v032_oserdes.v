
module dlsc_mt9v032_oserdes (
    // clocks and resets
    input   wire                    os_rst,         // synchronous to os_clk
    input   wire                    os_clk,         // px_clk * 9
    input   wire                    os_clk_fast,    // px_clk * 36
    input   wire                    os_strobe,      // serdes_strobe for os_clk_fast -> os_clk

    // single-ended clock output to image sensor
    output  wire                    clk_out,         // connect to top-level port
    
    // clk skew control (on os_clk domain)
    input   wire                    skew_en,
    input   wire                    skew_inc,
    output  reg                     skew_ack
);


// single-ended data output buffer

wire out_pre;

(* OUT_TERM = "UNTUNED_50" *) OBUF #(
    .IOSTANDARD ( "LVCMOS25" )  // Specify the output I/O standard
) OBUF_inst (
    .O          ( clk_out ),    // Buffer output (connect directly to top-level port)
    .I          ( out_pre )     // Buffer input 
);


// output serializer

reg [3:0] os_data;

OSERDES2 #(
    .BYPASS_GCLK_FF ( "FALSE" ),        // Bypass CLKDIV syncronization registers (TRUE/FALSE)
    .DATA_RATE_OQ   ( "SDR" ),          // Output Data Rate ("SDR" or "DDR")
    .DATA_RATE_OT   ( "SDR" ),          // 3-state Data Rate ("SDR" or "DDR")
    .DATA_WIDTH     ( 4 ),              // Parallel data width (2-8)
    .OUTPUT_MODE    ( "SINGLE_ENDED" ), // "SINGLE_ENDED" or "DIFFERENTIAL" 
    .SERDES_MODE    ( "NONE" ),         // "NONE", "MASTER" or "SLAVE" 
    .TRAIN_PATTERN  ( 0 )               // Training Pattern (0-15)
)
OSERDES2_inst (
    .CLK0       ( os_clk_fast ),        // 1-bit I/O clock input
    .CLK1       ( 1'b0 ),               // 1-bit Secondary I/O clock input
    .IOCE       ( os_strobe ),          // 1-bit Data strobe input
    .CLKDIV     ( os_clk ),             // 1-bit Logic domain clock input
    .OCE        ( 1'b1 ),               // 1-bit Clock enable input
    .TCE        ( 1'b1 ),               // 1-bit 3-state clock enable input
    
    .RST        ( os_rst ),             // 1-bit Asynchrnous reset input
    .TRAIN      ( 1'b0 ),               // 1-bit Training pattern enable input
    
    .OQ         ( out_pre ),            // 1-bit Data output to pad or IODELAY2
    .TQ         (  ),                   // 1-bit 3-state output to pad or IODELAY2
    
    // D1 - D4: 1-bit (each) Parallel data inputs
    .D1         ( os_data[0] ),
    .D2         ( os_data[1] ),
    .D3         ( os_data[2] ),
    .D4         ( os_data[3] ),    
    
    // T1 - T4: 1-bit (each) 3-state control inputs
    .T1         ( 1'b0 ),
    .T2         ( 1'b0 ),
    .T3         ( 1'b0 ),
    .T4         ( 1'b0 ),
    
    .SHIFTIN1   ( 1'b1 ),               // 1-bit Cascade data input
    .SHIFTIN2   ( 1'b1 ),               // 1-bit Cascade 3-state input
    .SHIFTIN3   ( 1'b1 ),               // 1-bit Cascade differential data input
    .SHIFTIN4   ( 1'b1 ),               // 1-bit Cascade differential 3-state input
    
    .SHIFTOUT1  (  ),                   // 1-bit Cascade data output
    .SHIFTOUT2  (  ),                   // 1-bit Cascade 3-state output
    .SHIFTOUT3  (  ),                   // 1-bit Cascade differential data output
    .SHIFTOUT4  (  )                    // 1-bit Cascade differential 3-state output
);


// clock pattern generation

reg [35:0] clk_pattern;

always @(posedge os_clk) begin
    if(os_rst) begin
        clk_pattern <= { {18{1'b1}}, {18{1'b0}} };
        skew_ack    <= 1'b0;
    end else begin
        if(!skew_en) begin
            skew_ack    <= 1'b0;
        end

        if(skew_en && !skew_ack) begin
            skew_ack    <= 1'b1;

            if(skew_inc) begin
                // need to increase data delay relative to sampling clock
                // -> increase output clock delay
                clk_pattern <= { clk_pattern[34:0], clk_pattern[35] };
            end else begin
                // need to decrease data delay relative to sampling clock
                // -> decrease output clock delay
                clk_pattern <= { clk_pattern[0], clk_pattern[35:1] };
            end
        end
    end
end

// mux clock pattern to oserdes

reg [3:0] pi;

always @(posedge os_clk) begin
    if(os_rst) begin
        pi          <= 0;
        os_data     <= 0;
    end else begin
        // wrap at 9
        if(pi == 4'd8)  pi <= 0;
        else            pi <= pi + 1;

        os_data     <= clk_pattern[ (pi*4) +: 4 ];
    end
end

endmodule


