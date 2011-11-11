
module mt9v032_iserdes #(
    parameter SWAP      = 0                         // set SWAP if p/n top-level ports are swapped
) (
    // clocks and resets
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

    // debug (synchronous to clk_2x)
    output  reg     [7:0]           iod_cnt,
    output  reg     [7:0]           skew_cnt,
    
    // iodelay
    input   wire                    iod_rst,        // reset should only be applied once after initial calibration
    input   wire                    iod_mask,       // prevent inc/dec operations
    input   wire                    iod_cal,        // slave must be periodically re-calibrated
    input   wire                    iod_cal_master, // master should only be calibrated once at power-up
    output  wire                    iod_busy,

    // clk skew control (on clk_2x domain)
    input   wire                    skew_inhibit,   // prevents clock skew changes when asserted
    output  reg                     skew_en,
    output  reg                     skew_inc,
    input   wire                    skew_ack
);

wire            out_en;
wire    [11:0]  out_data;
wire            pd_valid;
wire            pd_inc;
wire            iod_en;
wire            iod_inc;
wire            bitslip_busy;
reg             bitslip_en;

dlsc_mt9v032_iserdes_ip #(
    .SWAP       ( SWAP )
) dlsc_mt9v032_iserdes_ip (
    .rst_2x         ( rst_2x ),
    .clk_2x         ( clk_2x ),
    .clk_12x        ( clk_12x ),
    .strobe_12to2   ( strobe_12to2 ),
    .in_p           ( in_p ),
    .in_n           ( in_n ),
    .out_en         ( out_en ),
    .out_data       ( out_data ),
    .pd_valid       ( pd_valid ),
    .pd_inc         ( pd_inc ),
    .iod_rst        ( iod_rst ),
    .iod_cal        ( iod_cal ),
    .iod_cal_master ( iod_cal_master ),
    .iod_busy       ( iod_busy ),
    .iod_en         ( iod_en ),
    .iod_inc        ( iod_inc ),
    .bitslip_busy   ( bitslip_busy ),
    .bitslip_en     ( bitslip_en )
);

// latch out_data
reg     [9:0]   data_pre;

always @(posedge clk_2x) begin
    if(out_en) begin
        data_pre <= out_data[10:1];
    end
end

// check for mismatch against expected start/stop pattern
reg             train_done_pre;
always @(posedge clk_2x) begin
    if(rst_2x) begin
        bitslip_en      <= 1'b0;
        train_done_pre  <= 1'b0;
    end else begin
        bitslip_en      <= 1'b0;
        if(!bitslip_busy && out_en) begin
            if( out_data[11] != 1'b0 || out_data[0] != 1'b1 ) begin
                bitslip_en      <= 1'b1;
                train_done_pre  <= 1'b0;
            end
            if( out_data == 12'b0_00000_00000_1 ) begin
                train_done_pre  <= 1'b1;
            end
        end
    end
end

// transfer outputs to 'clk' domain
always @(posedge clk) begin
    data        <= data_pre;
    train_done  <= train_done_pre;
end


// *** phase alignment ***

// each tap is worth ~13ps-~43ps
//   limit overall range to +- ~1.3ns (< 1/2 bit time)
//   clock skew can be adjusted in 1.11ns increments
//   would prefer iodelay always have range > +- 550ps to prevent skew oscillation,
//   but may not be practical given potential tap variation

wire            iod_max = ( iod_cnt == 8'b00011111 ); // +31
wire            iod_min = ( iod_cnt == 8'b11100001 ); // -31

assign iod_en   = !iod_mask && pd_valid && ( !iod_max || !pd_inc ) && ( !iod_min || pd_inc );
assign iod_inc  = iod_en && pd_inc;

// track how far IODELAY is from center
always @(posedge clk_2x) begin
    if(iod_rst) begin
        iod_cnt     <= 0;
    end else begin
        if(iod_en && !iod_busy) begin
            if(iod_inc) iod_cnt <= iod_cnt + 1;
            else        iod_cnt <= iod_cnt - 1;
        end
    end
end

// generate clock skew control
reg     [11:0]  skew_delay;
wire            skew_delay_max = &skew_delay;

always @(posedge clk_2x) begin
    if(iod_rst) begin
        skew_en     <= 1'b0;
        skew_inc    <= 1'b0;
        skew_delay  <= 0;
        skew_cnt    <= 0;
    end else begin
        // increment to max
        if(!skew_delay_max) begin
            skew_delay  <= skew_delay + 1;
        end

        // reset request once acknowledged
        if(skew_ack) begin
            skew_en     <= 1'b0;
            skew_inc    <= 1'b0;
            skew_delay  <= 0;
        end

        // only allow new request if one isn't pending, and enough time has elapsed
        if(pd_valid && skew_delay_max && !skew_en && !skew_ack && !skew_inhibit) begin
            if(iod_max && pd_inc) begin
                skew_en     <= 1'b1;
                skew_inc    <= 1'b1;
                skew_cnt    <= skew_cnt + 1;
            end else if(iod_min && !pd_inc) begin
                skew_en     <= 1'b1;
                skew_inc    <= 1'b0;
                skew_cnt    <= skew_cnt - 1;
            end
        end
    end
end

endmodule

