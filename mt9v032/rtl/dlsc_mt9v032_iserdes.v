
module dlsc_mt9v032_iserdes #(
    parameter SWAP                  = 0,            // set SWAP if p/n top-level ports are swapped
    parameter SIM_TAPDELAY_VALUE    = 30
) (
    // clocks and resets
    input   wire                    rst,            // synchronous to clk
    input   wire                    clk,            // px_clk * 2
    input   wire                    clk_en,         // enable for clk -> px_clk
    input   wire                    clk_fast,       // px_clk * 12
    input   wire                    strobe,         // serdes_strobe for clk_fast -> clk

    // LVDS data input from image sensor
    input   wire                    in_p,           // connect to top-level port
    input   wire                    in_n,           // connect to top-level port

    // deserializer output (qualified by clk_en)
    output  reg     [9:0]           out_data,

    // serial framing (bitslip) status
    input   wire                    bitslip_mask,
    output  reg                     bitslip_okay,
    output  reg                     bitslip_error,

    // phase detector status (filtered)
    output  reg                     pd_valid,
    output  reg                     pd_inc,

    // iodelay calibration
    input   wire                    iod_rst_slave,
    input   wire                    iod_rst_master,
    input   wire                    iod_cal_slave,
    input   wire                    iod_cal_master,

    // iodelay control
    output  wire                    iod_busy,
    input   wire                    iod_en,
    input   wire                    iod_inc
);

// *** differential data input buffer ***

wire in_buffered;
wire in_buffered_swap;

wire zero   = 1'b0;
wire one    = 1'b1;

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

wire in_delayed_p;
wire in_delayed_n;

wire iod_busy_master;
wire iod_busy_slave;

assign iod_busy = iod_busy_master || iod_busy_slave;

IODELAY2 #(
    .COUNTER_WRAPAROUND ( "STAY_AT_LIMIT" ),        // "STAY_AT_LIMIT" or "WRAPAROUND" 
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
    .CLK        ( clk ),            // 1-bit Clock input
    .IOCLK0     ( clk_fast ),       // 1-bit Input from the I/O clock network
    .IOCLK1     ( zero),            // 1-bit Input from the I/O clock network
    
    .RST        ( iod_rst_master ), // 1-bit Reset to zero or 1/2 of total delay period
    .CE         ( iod_en ),         // 1-bit Enable INC input
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
    .COUNTER_WRAPAROUND ( "STAY_AT_LIMIT" ),        // "STAY_AT_LIMIT" or "WRAPAROUND" 
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
    .CLK        ( clk ),            // 1-bit Clock input
    .IOCLK0     ( clk_fast ),       // 1-bit Input from the I/O clock network
    .IOCLK1     ( zero ),           // 1-bit Input from the I/O clock network
    
    .RST        ( iod_rst_slave ),  // 1-bit Reset to zero or 1/2 of total delay period
    .CE         ( iod_en ),         // 1-bit Enable INC input
    .INC        ( iod_inc ),        // 1-bit Increment / decrement input
    .CAL        ( iod_cal_slave ),  // 1-bit Initiate calibration input
    .BUSY       ( iod_busy_slave ), // 1-bit Busy output after CAL
    
    .IDATAIN    ( in_buffered ),    // 1-bit Data input (connect to top-level port or I/O buffer)
    .DATAOUT    ( in_delayed_n ),   // 1-bit Delayed data output to ISERDES/input register
    
    .DATAOUT2   (  ),               // 1-bit Delayed data output to general FPGA fabric
    .DOUT       (  ),               // 1-bit Delayed data output
    .TOUT       (  ),               // 1-bit Delayed 3-state output
    
    .ODATAIN    ( zero ),           // 1-bit Output data input from output register or OSERDES2.
    .T          ( one )             // 1-bit 3-state input signal
);


`ifdef SIMULATION

// TODO: hack to work around IODELAY2 simulation model issues

always @(posedge iod_cal_master) begin
    force IODELAY2_master_inst.ignore_rst = 1'b0;
    force IODELAY2_slave_inst.ignore_rst = 1'b0;
    #0;
    release IODELAY2_master_inst.ignore_rst;
    release IODELAY2_slave_inst.ignore_rst;
end

`endif


// *** input deserializers ***

reg             bitslip_busy;
reg             bitslip_en;

wire            is_bitslip      = bitslip_en && !bitslip_busy;

wire            is_pd_valid;
wire            is_pd_inc;

wire    [5:0]   is_data;

wire            master_cascade;
wire            slave_cascade;

ISERDES2 #(
    .BITSLIP_ENABLE ( "TRUE" ),     // Enable Bitslip Functionality (TRUE/FALSE)
    .DATA_RATE      ( "SDR" ),      // Data-rate ("SDR" or "DDR")
    .DATA_WIDTH     ( 6 ),          // Parallel data width selection (2-8)
    .INTERFACE_TYPE ( "RETIMED" ),  // "NETWORKING", "NETWORKING_PIPELINED" or "RETIMED" 
    .SERDES_MODE    ( "MASTER" )    // "NONE", "MASTER" or "SLAVE" 
) ISERDES2_master_inst (
    .CLK0       ( clk_fast ),       // 1-bit I/O clock network input
    .CLK1       ( zero ),           // 1-bit Secondary I/O clock network input
    .IOCE       ( strobe ),         // 1-bit Data strobe input
    .CLKDIV     ( clk ),            // 1-bit FPGA logic domain clock input
    .CE0        ( one ),            // 1-bit Clock enable input
    
    .RST        ( rst ),            // 1-bit Asynchronous reset input
    .BITSLIP    ( is_bitslip ),     // 1-bit Bitslip enable input
    
    .VALID      ( is_pd_valid ),    // 1-bit Output status of the phase detector
    .INCDEC     ( is_pd_inc ),      // 1-bit Phase detector output
    
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
    .CLK0       ( clk_fast ),       // 1-bit I/O clock network input
    .CLK1       ( zero ),           // 1-bit Secondary I/O clock network input
    .IOCE       ( strobe ),         // 1-bit Data strobe input
    .CLKDIV     ( clk ),            // 1-bit FPGA logic domain clock input
    .CE0        ( one ),            // 1-bit Clock enable input
    
    .RST        ( rst ),            // 1-bit Asynchronous reset input
    .BITSLIP    ( is_bitslip ),     // 1-bit Bitslip enable input
    
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


// ** phase detector filter **

reg     [4:0]   pd_filter;
wire            pd_max      = (pd_filter == 5'b01111); // +15
wire            pd_min      = (pd_filter == 5'b10001); // -15

always @(posedge clk) begin
    if(iod_rst_slave || iod_en) begin
        pd_filter   <= 0;
        pd_valid    <= 1'b0;
        pd_inc      <= 1'b0;
    end else begin
        pd_valid    <= 1'b0;
//      pd_inc      <= 1'b0;    // hold last value
        if(is_pd_valid) begin
            if(is_pd_inc) begin
                // increment filter
                if(pd_max) begin
                    // saturated; drive output and reset filter
                    pd_filter   <= 0;
                    pd_valid    <= 1'b1;
                    pd_inc      <= 1'b1;
                end else begin
                    pd_filter   <= pd_filter + 1;
                end
            end else begin
                // decrement filter
                if(pd_min) begin
                    // saturated; drive output and reset filter
                    pd_filter   <= 0;
                    pd_valid    <= 1'b1;
                    pd_inc      <= 1'b0;
                end else begin
                    pd_filter   <= pd_filter - 1;
                end
            end
        end
    end
end


// ** bitslip masking **

reg     [3:0]   bs_mask;

always @(posedge clk) begin
    if(rst) begin
        bitslip_busy    <= 1'b1;
        bs_mask         <= 0;
    end else begin
        if(&bs_mask) begin
            // masking done
            bitslip_busy    <= 1'b0;
        end else begin
            bs_mask         <= bs_mask + 1;
        end
        if(is_bitslip) begin
            // request accepted; mask new requests for a bit
            bitslip_busy    <= 1'b1;
            bs_mask         <= 0;
        end
    end
end


// ** bitslip words **

reg     [2:0]   bs_cnt;
wire            bs_max      = (bs_cnt == 3'd5);     // 6:1 ISERDES, so 6 possible slip states..
wire            bs_word     = is_bitslip && bs_max;

always @(posedge clk) begin
    if(rst) begin
        bs_cnt          <= 0;
    end else begin
        if(is_bitslip) begin
            if(bs_max) bs_cnt <= 0;
            else       bs_cnt <= bs_cnt + 1;
        end
    end
end


// ** output **

reg             data_en;
wire            next_data_en    = !data_en ^ bs_word;

always @(posedge clk) begin
    if(rst) begin
        data_en         <= 1'b0;
    end else begin
        data_en         <= next_data_en;
    end
end

reg  [5:0]      is_data_prev;
reg  [11:0]     data;
wire            framing_okay    = ((data[11] == 1'b0) && (data[0] == 1'b1));

always @(posedge clk) begin
    is_data_prev    <= is_data;
    if(next_data_en) begin
        // have complete word now
        data            <= { is_data, is_data_prev };
    end
end

always @(posedge clk) begin
    if( !(bitslip_okay && framing_okay && !bitslip_mask) ) begin
        // don't drive bad data
        out_data    <= 10'd0;
    end else if(clk_en) begin
        // transfer data to px_clk
        out_data    <= data[10:1];
    end
end


// ** bitslip checking **

reg  [11:0]     bitslip_okay_cnt;

always @(posedge clk) begin
    if(rst) begin
        bitslip_okay_cnt<= 0;
        bitslip_okay    <= 1'b0;
        bitslip_error   <= 1'b0;
        bitslip_en      <= 1'b0;
    end else begin

        bitslip_error   <= 1'b0;
        bitslip_en      <= 1'b0;

        if(framing_okay && clk_en) begin
            if(&bitslip_okay_cnt) begin
                bitslip_okay    <= 1'b1;
            end else begin
                bitslip_okay_cnt<= bitslip_okay_cnt + 1;
            end
        end

        if(!framing_okay) begin
            bitslip_en      <= 1'b1;
            if( !(bitslip_mask && bitslip_okay) ) begin
                bitslip_okay_cnt<= 0;
                bitslip_okay    <= 1'b0;
                bitslip_error   <= bitslip_okay;
            end
        end
        
    end
end


endmodule

