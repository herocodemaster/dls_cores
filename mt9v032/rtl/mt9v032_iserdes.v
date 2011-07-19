
module mt9v032_iserdes #(
    parameter SWAP      = 0                         // set SWAP if p/n top-level ports are swapped
) (
    // clocks and resets
    input   wire                    rst,            // synchronous to clk
    input   wire                    rst_2x,         // synchronous to clk_2x
    input   wire                    clk,            // pixel clock
    input   wire                    clk_2x,         // clk * 2
    input   wire                    clk_12x,        // clk * 12
    input   wire                    strobe_12to2,   // serdes_strobe for clk_12x -> clk_2x

    // LVDS data input from image sensor
    input   wire                    in_p,           // connect to top-level port
    input   wire                    in_n,           // connect to top-level port

    // status and deserialized data (synchronous to clk)
    output  reg     [9:0]           data,
    output  reg                     train_done,
    
    // iodelay
    input   wire                    iod_rst,        // reset should only be applied once after initial calibration
    input   wire                    iod_mask,       // prevent inc/dec operations
    input   wire                    iod_cal,        // slave must be periodically re-calibrated
    input   wire                    iod_cal_master, // master should only be calibrated once at power-up
    output  wire                    iod_busy,

    // clk skew control (on clk_2x domain)
    output  reg                     skew_en,
    output  reg                     skew_inc,
    input   wire                    skew_ack
);


// *** differential data input buffer ***

wire in_buffered;
wire in_buffered_swap;

wire zero = 1'b0;
wire one = 1'b1;

generate
    if(SWAP) begin:GEN_INVERT
        IBUFDS #(
            .DIFF_TERM  ( "TRUE" ),     // Differential Termination
            .IOSTANDARD ( "LVDS_25" )   // Specify the input I/O standard
        ) IBUFDS_inst (
            .O  ( in_buffered_swap ),   // Buffer output
            .I  ( in_n ),               // Diff_p buffer input (connect directly to top-level port)
            .IB ( in_p )                // Diff_n buffer input (connect directly to top-level port)
        );
        assign in_buffered = !in_buffered_swap;
    end else begin:GEN_NONINVERT
        IBUFDS #(
            .DIFF_TERM  ( "TRUE" ),     // Differential Termination
            .IOSTANDARD ( "LVDS_25" )   // Specify the input I/O standard
        ) IBUFDS_inst (
            .O  ( in_buffered_swap ),   // Buffer output
            .I  ( in_p ),               // Diff_p buffer input (connect directly to top-level port)
            .IB ( in_n )                // Diff_n buffer input (connect directly to top-level port)
        );
        assign in_buffered = in_buffered_swap;
    end
endgenerate


// *** input delays ***

localparam SIM_TAPDELAY_VALUE = 18;

wire in_delayed_p;
wire in_delayed_n;

wire iod_ce;
wire iod_inc;

wire iod_busy_master;
wire iod_busy_slave;

assign iod_busy = iod_busy_master || iod_busy_slave;

IODELAY2 #(
    .COUNTER_WRAPAROUND ( "WRAPAROUND" ),           // "STAY_AT_LIMIT" or "WRAPAROUND" 
    .DATA_RATE          ( "SDR" ),                  // "SDR" or "DDR" 
    .DELAY_SRC          ( "IDATAIN" ),              // "IO", "ODATAIN" or "IDATAIN" 
    .IDELAY2_VALUE      ( 0 ),                      // Delay value when IDELAY_MODE="PCI" (0-255)
    .IDELAY_MODE        ( "NORMAL" ),               // "NORMAL" or "PCI" 
    .IDELAY_TYPE        ( "DIFF_PHASE_DETECTOR" ),  // "FIXED", "DEFAULT", "VARIABLE_FROM_ZERO", "VARIABLE_FROM_HALF_MAX" 
                                                    // or "DIFF_PHASE_DETECTOR" 
    .IDELAY_VALUE       ( 0 ),                      // Amount of taps for fixed input delay (0-255)
    .ODELAY_VALUE       ( 0 ),                      // Amount of taps fixed output delay (0-255)
    .SERDES_MODE        ( "MASTER" ),               // "NONE", "MASTER" or "SLAVE" 
    .SIM_TAPDELAY_VALUE ( SIM_TAPDELAY_VALUE )      // Per tap delay used for simulation in ps
) IODELAY2_master_inst (
    .CLK        ( clk_2x ),         // 1-bit Clock input
    .IOCLK0     ( clk_12x ),        // 1-bit Input from the I/O clock network
    .IOCLK1     ( zero),            // 1-bit Input from the I/O clock network
    
    .RST        ( iod_rst ),        // 1-bit Reset to zero or 1/2 of total delay period
    .CE         ( iod_ce ),         // 1-bit Enable INC input
    .INC        ( iod_inc ),        // 1-bit Increment / decrement input
    .CAL        ( iod_cal_master ), // 1-bit Initiate calibration input
    .BUSY       ( iod_busy_master ),// 1-bit Busy output after CAL
    
    .IDATAIN    ( in_buffered ),    // 1-bit Data input (connect to top-level port or I/O buffer)
    .DATAOUT    ( in_delayed_p ),   // 1-bit Delayed data output to ISERDES/input register
    
    .DATAOUT2   (  ),               // 1-bit Delayed data output to general FPGA fabric
    .DOUT       (  ),               // 1-bit Delayed data output
    .TOUT       (  ),               // 1-bit Delayed 3-state output
    
    .ODATAIN    ( zero ),           // 1-bit Output data input from output register or OSERDES2.
    .T          ( one )             // 1-bit 3-state input signal
);

IODELAY2 #(
    .COUNTER_WRAPAROUND ( "WRAPAROUND" ),           // "STAY_AT_LIMIT" or "WRAPAROUND" 
    .DATA_RATE          ( "SDR" ),                  // "SDR" or "DDR" 
    .DELAY_SRC          ( "IDATAIN" ),              // "IO", "ODATAIN" or "IDATAIN" 
    .IDELAY2_VALUE      ( 0 ),                      // Delay value when IDELAY_MODE="PCI" (0-255)
    .IDELAY_MODE        ( "NORMAL" ),               // "NORMAL" or "PCI" 
    .IDELAY_TYPE        ( "DIFF_PHASE_DETECTOR" ),  // "FIXED", "DEFAULT", "VARIABLE_FROM_ZERO", "VARIABLE_FROM_HALF_MAX" 
                                                    // or "DIFF_PHASE_DETECTOR" 
    .IDELAY_VALUE       ( 0 ),                      // Amount of taps for fixed input delay (0-255)
    .ODELAY_VALUE       ( 0 ),                      // Amount of taps fixed output delay (0-255)
    .SERDES_MODE        ( "SLAVE" ),                // "NONE", "MASTER" or "SLAVE" 
    .SIM_TAPDELAY_VALUE ( SIM_TAPDELAY_VALUE )      // Per tap delay used for simulation in ps
) IODELAY2_slave_inst (
    .CLK        ( clk_2x ),         // 1-bit Clock input
    .IOCLK0     ( clk_12x ),        // 1-bit Input from the I/O clock network
    .IOCLK1     ( zero ),           // 1-bit Input from the I/O clock network
    
    .RST        ( iod_rst ),        // 1-bit Reset to zero or 1/2 of total delay period
    .CE         ( iod_ce ),         // 1-bit Enable INC input
    .INC        ( iod_inc ),        // 1-bit Increment / decrement input
    .CAL        ( iod_cal ),        // 1-bit Initiate calibration input
    .BUSY       ( iod_busy_slave ), // 1-bit Busy output after CAL
    
    .IDATAIN    ( in_buffered ),    // 1-bit Data input (connect to top-level port or I/O buffer)
    .DATAOUT    ( in_delayed_n ),   // 1-bit Delayed data output to ISERDES/input register
    
    .DATAOUT2   (  ),               // 1-bit Delayed data output to general FPGA fabric
    .DOUT       (  ),               // 1-bit Delayed data output
    .TOUT       (  ),               // 1-bit Delayed 3-state output
    
    .ODATAIN    ( zero ),           // 1-bit Output data input from output register or OSERDES2.
    .T          ( one )             // 1-bit 3-state input signal
);


// *** input deserializers ***

reg             is_bitslip;
wire            is_bitslip_net = is_bitslip;

wire    [5:0]   is_data;

wire            pd_valid;
wire            pd_incdec;

wire            master_cascade;
wire            slave_cascade;

ISERDES2 #(
    .BITSLIP_ENABLE ( "TRUE" ),     // Enable Bitslip Functionality (TRUE/FALSE)
    .DATA_RATE      ( "SDR" ),      // Data-rate ("SDR" or "DDR")
    .DATA_WIDTH     ( 6 ),          // Parallel data width selection (2-8)
    .INTERFACE_TYPE ( "RETIMED" ),  // "NETWORKING", "NETWORKING_PIPELINED" or "RETIMED" 
    .SERDES_MODE    ( "MASTER" )    // "NONE", "MASTER" or "SLAVE" 
) ISERDES2_master_inst (
    .CLK0       ( clk_12x ),        // 1-bit I/O clock network input
    .CLK1       ( zero ),           // 1-bit Secondary I/O clock network input
    .IOCE       ( strobe_12to2 ),   // 1-bit Data strobe input
    .CLKDIV     ( clk_2x ),         // 1-bit FPGA logic domain clock input
    .CE0        ( one ),            // 1-bit Clock enable input
    
    .RST        ( rst_2x ),         // 1-bit Asynchronous reset input
    .BITSLIP    ( is_bitslip_net ), // 1-bit Bitslip enable input
    
    .VALID      ( pd_valid ),       // 1-bit Output status of the phase detector
    .INCDEC     ( pd_incdec ),      // 1-bit Phase detector output
    
    .D          ( in_delayed_p ),   // 1-bit Input data
    
    // Q1 - Q4: 1-bit (each) Registered outputs to FPGA logic
    .Q1         ( is_data[2] ),
    .Q2         ( is_data[3] ),
    .Q3         ( is_data[4] ),
    .Q4         ( is_data[5] ),
    
    .SHIFTOUT   ( master_cascade ), // 1-bit Cascade output signal for master/slave I/O
    .SHIFTIN    ( slave_cascade ),  // 1-bit Cascade input signal for master/slave I/O
    
    .CFB0       (  ),               // 1-bit Clock feed-through route output
    .CFB1       (  ),               // 1-bit Clock feed-through route output
    .DFB        (  ),               // 1-bit Feed-through clock output
    .FABRICOUT  (  )                // 1-bit Unsynchrnonized data output
);

ISERDES2 #(
    .BITSLIP_ENABLE ( "TRUE" ),     // Enable Bitslip Functionality (TRUE/FALSE)
    .DATA_RATE      ( "SDR" ),      // Data-rate ("SDR" or "DDR")
    .DATA_WIDTH     ( 6 ),          // Parallel data width selection (2-8)
    .INTERFACE_TYPE ( "RETIMED" ),  // "NETWORKING", "NETWORKING_PIPELINED" or "RETIMED" 
    .SERDES_MODE    ( "SLAVE" )     // "NONE", "MASTER" or "SLAVE" 
) ISERDES2_slave_inst (
    .CLK0       ( clk_12x ),        // 1-bit I/O clock network input
    .CLK1       ( zero ),           // 1-bit Secondary I/O clock network input
    .IOCE       ( strobe_12to2 ),   // 1-bit Data strobe input
    .CLKDIV     ( clk_2x ),         // 1-bit FPGA logic domain clock input
    .CE0        ( one ),            // 1-bit Clock enable input
    
    .RST        ( rst_2x ),         // 1-bit Asynchronous reset input
    .BITSLIP    ( is_bitslip_net ), // 1-bit Bitslip enable input
    
    .VALID      (  ),               // 1-bit Output status of the phase detector
    .INCDEC     (  ),               // 1-bit Phase detector output
    
    .D          ( in_delayed_n ),   // 1-bit Input data
    
    // Q1 - Q4: 1-bit (each) Registered outputs to FPGA logic
    .Q1         (  ),
    .Q2         (  ),
    .Q3         ( is_data[0] ),
    .Q4         ( is_data[1] ),
    
    .SHIFTOUT   ( slave_cascade ),  // 1-bit Cascade output signal for master/slave I/O
    .SHIFTIN    ( master_cascade ), // 1-bit Cascade input signal for master/slave I/O
    
    .CFB0       (  ),               // 1-bit Clock feed-through route output
    .CFB1       (  ),               // 1-bit Clock feed-through route output
    .DFB        (  ),               // 1-bit Feed-through clock output
    .FABRICOUT  (  )                // 1-bit Unsynchrnonized data output
);


// *** data output ***

// generate xfer_en
reg             xfer_en;        // enable for bs_data -> data transfer
reg             bs_data_slip;

always @(posedge clk_2x or posedge rst_2x) begin
    if(rst_2x) begin
        xfer_en     <= 1'b0;
    end else if(!bs_data_slip) begin
        xfer_en     <= !xfer_en;
    end
end

// fill bs_data
reg     [11:0]  bs_data;

always @(posedge clk_2x) begin
    bs_data     <= { is_data, bs_data[11:6] };
end

// latch bs_data
reg     [9:0]   data_pre;

always @(posedge clk_2x) begin
    if(xfer_en) begin
        data_pre <= bs_data[10:1];
    end
end

// only evaluate bitslip periodically
reg     [3:0]   bs_div;
reg             bs_eval;

always @(posedge clk_2x or posedge rst_2x) begin
    if(rst_2x) begin
        bs_eval <= 1'b0;
        bs_div  <= 0;
    end else begin
        if(xfer_en) begin
            bs_div  <= bs_div + 1;
        end
        
        bs_eval <= &bs_div && xfer_en;
    end
end

// check for mismatch against expected start/stop pattern
reg             bs_mismatch;
reg             bs_mask;
reg             train_done_pre;
always @(posedge clk_2x or posedge rst_2x) begin
    if(rst_2x) begin
        bs_mismatch     <= 1'b0;
        bs_mask         <= 1'b1;
        train_done_pre  <= 1'b0;
    end else begin
        if(xfer_en && !bs_mask) begin
            if( bs_data[11] != 1'b0 || bs_data[0] != 1'b1 ) begin
                bs_mismatch     <= 1'b1;
                train_done_pre  <= 1'b0;
            end
            if( bs_data == 12'b0_00000_00000_1 ) begin
                train_done_pre  <= 1'b1;
            end
        end
        // clear mismatch after each slip, and mask comparisons until next eval
        if(is_bitslip) begin
            bs_mismatch     <= 1'b0;
            bs_mask         <= 1'b1;
            train_done_pre  <= 1'b0;
        end
        if(bs_eval) begin
            bs_mask         <= 1'b0;
        end
    end
end

// transfer outputs to 'clk' domain
always @(posedge clk) begin
    data        <= data_pre;
    train_done  <= train_done_pre;
end

// bitslip control logic
reg     [1:0]   is_bitslip_cnt; // count of ISERDES bitslip operations - must invoke bs_data slip when it rolls over

always @(posedge clk_2x or posedge rst_2x) begin
    if(rst_2x) begin
        bs_data_slip    <= 1'b0;
        is_bitslip      <= 1'b0;
        is_bitslip_cnt  <= 1'b0;
    end else begin
        bs_data_slip    <= 1'b0;
        is_bitslip      <= 1'b0;

        if(bs_eval && bs_mismatch) begin
            is_bitslip      <= 1'b1;
            is_bitslip_cnt  <= is_bitslip_cnt + 1;
            if(&is_bitslip_cnt) begin
                bs_data_slip    <= 1'b1;
            end
        end        
    end
end


// *** phase alignment ***

// filter phase-detector output
reg     [2:0]   pd_filter;
reg             pd_fvalid;
reg             pd_fincdec;

always @(posedge clk_2x or posedge rst_2x) begin
    if(rst_2x) begin
        pd_filter   <= 3'b100;
        pd_fvalid   <= 1'b0;
        pd_fincdec  <= 1'b0;
    end else begin
        // only clear request once it is accepted
        if(iod_busy) begin
            pd_fvalid   <= 1'b0;
            pd_fincdec  <= 1'b0;
        end

        // don't issue request if one is pending, IODELAY is busy, or it is externally masked
        if(pd_valid && !pd_fvalid && !iod_busy && !iod_mask) begin
            if(pd_incdec) begin
                if(pd_filter == 3'b111) begin
                    pd_filter   <= 3'b100;
                    pd_fvalid   <= 1'b1;
                    pd_fincdec  <= 1'b1;
                end else begin
                    pd_filter   <= pd_filter + 1;
                end
            end else begin
                if(pd_filter == 3'b001) begin
                    pd_filter   <= 3'b100;
                    pd_fvalid   <= 1'b1;
                    pd_fincdec  <= 1'b0;
                end else begin
                    pd_filter   <= pd_filter - 1;
                end
            end
        end
    end
end

// each tap is worth ~13ps-~43ps
//   limit overall range to +- ~1.3ns (< 1/2 bit time)
//   clock skew can be adjusted in 1.11ns increments
//   would prefer iodelay always have range > +- 550ps to prevent skew oscillation,
//   but may not be practical given potential tap variation

reg     [5:0]   iod_cnt;

wire            iod_max = ( iod_cnt == 6'b111111 );
wire            iod_min = ( iod_cnt == 6'b000001 );

assign iod_ce   = pd_fvalid && ( !iod_max || !pd_fincdec ) && ( !iod_min || pd_fincdec );
assign iod_inc  = pd_fincdec && iod_ce;

// track how far IODELAY is from center
always @(posedge clk_2x or posedge iod_rst) begin
    if(iod_rst) begin
        iod_cnt     <= 4'b1000;
    end else begin
        if(iod_ce && !iod_busy) begin
            if(iod_inc) iod_cnt <= iod_cnt + 1;
            else        iod_cnt <= iod_cnt - 1;
        end
    end
end

// generate clock skew control
reg [11:0] skew_delay;
always @(posedge clk_2x or posedge iod_rst) begin
    if(iod_rst) begin
        skew_en     <= 1'b0;
        skew_inc    <= 1'b0;
        skew_delay  <= 0;
    end else begin
        // increment to max
        if( !(&skew_delay) ) begin
            skew_delay  <= skew_delay + 1;
        end

        // reset request once acknowledged
        if(skew_ack) begin
            skew_en     <= 1'b0;
            skew_inc    <= 1'b0;
            skew_delay  <= 0;
        end

        // only allow new request if one isn't pending, and enough time has elapsed
        if(pd_fvalid && &skew_delay && !skew_en && !skew_ack) begin
            if(iod_max && pd_fincdec) begin
                skew_en     <= 1'b1;
                skew_inc    <= 1'b1;
            end else if(iod_min && !pd_fincdec) begin
                skew_en     <= 1'b1;
                skew_inc    <= 1'b0;
            end
        end
    end
end

endmodule

