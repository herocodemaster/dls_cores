
module dlsc_mt9v032_control #(
    parameter APB_ADDR          = 32,
    parameter HDISP             = 752,
    parameter VDISP             = 480
) (
    // system
    input   wire                    clk,
    input   wire                    rst_in,
    output  wire                    rst_out,
    
    // APB register bus
    input   wire    [APB_ADDR-1:0]  apb_addr,
    input   wire                    apb_sel,
    input   wire                    apb_enable,
    input   wire                    apb_write,
    input   wire    [31:0]          apb_wdata,
    input   wire    [3:0]           apb_strb,
    output  reg                     apb_ready,
    output  reg     [31:0]          apb_rdata,

    // interrupt
    output  reg                     int_out,

    // pipeline control
    output  reg                     pipeline_enable,
    input   wire                    pipeline_overrun,
    input   wire                    pipeline_disabled,

    // timing control (to timing)
    output  reg     [9:0]           hdisp,
    output  reg     [9:0]           vdisp,

    // timing status (from timing)
    input   wire    [9:0]           obs_hdisp,
    input   wire    [9:0]           obs_vdisp,
    input   wire                    res_okay,
    input   wire                    res_error,
    input   wire                    sync_error,
    input   wire                    frame_start,
    input   wire                    frame_end,
    input   wire                    frame_valid,

    // bitslip status (from iserdes)
    output  reg                     bitslip_mask,   // ignore bitslip errors
    input   wire                    bitslip_okay,
    input   wire                    bitslip_error,

    // phase detector status (from iserdes)
    input   wire                    pd_valid,
    input   wire                    pd_inc,

    // IOD control (to iserdes)
    input   wire                    iod_busy,
    output  reg                     iod_rst_slave,
    output  reg                     iod_rst_master,
    output  reg                     iod_cal_slave,
    output  reg                     iod_cal_master,
    output  reg                     iod_en,
    output  reg                     iod_inc,

    // skew control (to oserdes)    
    output  reg                     skew_en,
    output  reg                     skew_inc,
    input   wire                    skew_ack
);

localparam  REG_CONTROL     = 3'h0,
            REG_STATUS      = 3'h1,
            REG_INT_FLAGS   = 3'h2,
            REG_INT_SELECT  = 3'h3,
            REG_HDISP       = 3'h4,
            REG_VDISP       = 3'h5,
            REG_HDISP_OBS   = 3'h6,
            REG_VDISP_OBS   = 3'h7;

// 0x0: control (RW)
//  [0]     : enable interface
//  [1]     : enable pipeline output (automatically cleared by fatal errors)
// 0x1: status flags (RO)
//  [0]     : serial framing okay
//  [1]     : interface ready (complete frame observed)
//  [2]     : output ready (complete frame observed with correct resolution)
//  [5:4]   : skew_val
//  [15:8]  : iod_val
// 0x2: interrupt flags (write 1 to clear)
//  [0]     : serial framing okay
//  [1]     : interface ready
//  [2]     : output ready
//  [3]     : skew change done
//  [4]     : frame start
//  [5]     : frame done
//  [6]     : serial framing error
//  [7]     : sync error
//  [8]     : resolution error
//  [9]     : pipeline output overrun
//  [10]    : pipeline output disabled externally
// 0x3: interrupt select
// 0x4: hdisp_expected (RW)
// 0x5: vdisp_expected (RW)
// 0x6: hdisp_observed (RO)
// 0x7: vdisp_observed (RO)

wire    [2:0]   csr_addr        = apb_addr[4:2];
wire    [31:0]  csr_wdata       = apb_wdata;
wire    [31:0]  csr_rd          = {32{(apb_sel && !apb_enable && !apb_write)}};
wire    [31:0]  csr_wr          = {32{(apb_sel && !apb_enable &&  apb_write)}} &
                                    { {8{apb_strb[3]}},{8{apb_strb[2]}},{8{apb_strb[1]}},{8{apb_strb[0]}} };


// set_ signals for interrupt flags
reg             set_serial_ready;
reg             set_interface_ready;
reg             set_output_ready;
reg             set_skew_done;

// status flags
reg             serial_ready;
reg             interface_ready_pre;
reg             interface_ready;
reg             output_ready;
reg  [7:0]      iod_val;
reg  [1:0]      skew_val;


// ** registers **

// control register
reg             ctrl_enable;
reg             pipeline_enable_pre;
reg             disable_change_rst;
reg             disable_change_cal;
reg             disable_skew_rst;
reg             disable_skew;
reg             force_skew;
reg             force_rst;
reg             report_all_errors;


wire [31:0]     csr_control     = { 23'd0,
                                    report_all_errors,
                                    force_rst,
                                    force_skew,
                                    disable_skew,
                                    disable_skew_rst,
                                    disable_change_cal,
                                    disable_change_rst,
                                    pipeline_enable_pre,
                                    ctrl_enable };

assign          rst_out         = rst_in || !ctrl_enable;

always @(posedge clk) begin
    if(rst_in) begin
        ctrl_enable         <= 1'b0;
        pipeline_enable_pre <= 1'b0;
        pipeline_enable     <= 1'b0;
        disable_change_rst  <= 1'b0;
        disable_change_cal  <= 1'b0;
        disable_skew_rst    <= 1'b0;
        disable_skew        <= 1'b0;
        force_skew          <= 1'b0;
        force_rst           <= 1'b0;
        report_all_errors   <= 1'b0;
    end else begin

        if(csr_addr == REG_CONTROL) begin
            if(csr_wr[0]) ctrl_enable           <= csr_wdata[0];
            if(csr_wr[1]) pipeline_enable_pre   <= csr_wdata[1];
            if(csr_wr[2]) disable_change_rst    <= csr_wdata[2];
            if(csr_wr[3]) disable_change_cal    <= csr_wdata[3];
            if(csr_wr[4]) disable_skew_rst      <= csr_wdata[4];
            if(csr_wr[5]) disable_skew          <= csr_wdata[5];
            if(csr_wr[6]) force_skew            <= csr_wdata[6];
            if(csr_wr[7]) force_rst             <= csr_wdata[7];
            if(csr_wr[8]) report_all_errors     <= csr_wdata[8];
        end

        if(pipeline_enable_pre && !frame_valid) begin
            // pipeline_enable should only be set between frames
            pipeline_enable     <= 1'b1;
        end
        if(!pipeline_enable_pre) begin
            pipeline_enable     <= 1'b0;
        end

        if(!output_ready || pipeline_disabled ||
           bitslip_error || sync_error || res_error)
        begin
            pipeline_enable_pre <= 1'b0;
            pipeline_enable     <= 1'b0;
        end

        if(set_skew_done) begin
            force_skew          <= 1'b0;
        end

        if(iod_cal_master) begin
            force_rst           <= 1'b0;
        end

    end
end

// status register

reg  [31:0]     csr_status;
always @* begin
    csr_status      = 32'd0;
    csr_status[0]   = serial_ready;
    csr_status[1]   = interface_ready;
    csr_status[2]   = output_ready;
    csr_status[5:4] = skew_val;
    csr_status[15:8]= iod_val;
end

// interrupt flags

reg  [10:0]     int_flags;
reg  [10:0]     int_select;

wire [31:0]     csr_int_flags   = {21'd0,int_flags};
wire [31:0]     csr_int_select  = {21'd0,int_select};

always @(posedge clk) begin
    if(rst_in) begin
        int_flags       <= 0;
        int_select      <= 0;
        int_out         <= 1'b0;
    end else begin
        
        if(csr_addr == REG_INT_SELECT) begin
            int_select      <= (int_select & ~csr_wr[10:0]) | (csr_wdata[10:0] & csr_wr[10:0]);
        end
        if(csr_addr == REG_INT_FLAGS) begin
            // clear flags when written with a 1
            int_flags       <= int_flags & ~(csr_wr[10:0] & csr_wdata[10:0]);
        end

        if(ctrl_enable) begin
            if(set_serial_ready)    int_flags[0]    <= 1'b1;
            if(set_interface_ready) int_flags[1]    <= 1'b1;
            if(set_output_ready)    int_flags[2]    <= 1'b1;
            if(set_skew_done)       int_flags[3]    <= 1'b1;
            
            if(interface_ready || report_all_errors) begin
                if(frame_start)         int_flags[4]    <= 1'b1;
                if(frame_end)           int_flags[5]    <= 1'b1;
                if(bitslip_error)       int_flags[6]    <= 1'b1;
                if(sync_error)          int_flags[7]    <= 1'b1;
            end
            
            if(output_ready || report_all_errors) begin
                if(res_error)           int_flags[8]    <= 1'b1;
            end

            if(pipeline_enable) begin
                if(pipeline_overrun)    int_flags[9]    <= 1'b1;
                if(pipeline_disabled)   int_flags[10]   <= 1'b1;
            end
        end
        
        int_out         <= |(int_flags & int_select);

    end
end

// resolution

wire [31:0]     csr_hdisp       = { 22'd0, hdisp };
wire [31:0]     csr_vdisp       = { 22'd0, vdisp };
wire [31:0]     csr_hdisp_obs   = { 22'd0, obs_hdisp };
wire [31:0]     csr_vdisp_obs   = { 22'd0, obs_vdisp };

always @(posedge clk) begin
    if(rst_in) begin
        hdisp       <= HDISP;
        vdisp       <= VDISP;
    end else begin
        if(csr_addr == REG_HDISP) begin
            hdisp       <= (hdisp & ~csr_wr[9:0]) | (csr_wdata[9:0] & csr_wr[9:0]);
        end
        if(csr_addr == REG_VDISP) begin
            vdisp       <= (vdisp & ~csr_wr[9:0]) | (csr_wdata[9:0] & csr_wr[9:0]);
        end
    end
end

// register read

always @(posedge clk) begin
    apb_ready       <= (apb_sel && !apb_enable);
    apb_rdata       <= 32'd0;
    if(apb_sel && !apb_enable && !apb_write) begin
        case(csr_addr)
            REG_CONTROL:    apb_rdata <= csr_control;
            REG_STATUS:     apb_rdata <= csr_status;
            REG_INT_FLAGS:  apb_rdata <= csr_int_flags;
            REG_INT_SELECT: apb_rdata <= csr_int_select;
            REG_HDISP:      apb_rdata <= csr_hdisp;
            REG_VDISP:      apb_rdata <= csr_vdisp;
            REG_HDISP_OBS:  apb_rdata <= csr_hdisp_obs;
            REG_VDISP_OBS:  apb_rdata <= csr_vdisp_obs;
            default:        apb_rdata <= 0;
        endcase
    end
end


// track IOD changes

reg             iod_val_max;
reg             iod_val_min;

always @(posedge clk) begin
    if(iod_rst_master) begin
        iod_val     <= 0;
        iod_val_max <= 1'b0;
        iod_val_min <= 1'b0;
    end else if(iod_en) begin
        if( iod_inc && !iod_val_max) begin
            iod_val     <= iod_val + 1;
            iod_val_max <= (iod_val == 8'h7E);  // +126 (going to +127)
            iod_val_min <= 1'b0;
        end
        if(!iod_inc && !iod_val_min) begin
            iod_val     <= iod_val - 1;
            iod_val_max <= 1'b0;
            iod_val_min <= (iod_val == 8'h81);  // -127 (going to -128)
        end
    end
end

// track clock skew changes
// (3 possible skew settings: 0, 1/3rd, 2/3rd (of a bit time (3.125ns)))

always @(posedge clk) begin
    if(rst_out) begin
        skew_val    <= 0;
    end else if(skew_en && skew_ack) begin
        if(skew_inc) begin
            // mod-3 increment
            case(skew_val)
                2'd0:    skew_val <= 2'd1;
                2'd1:    skew_val <= 2'd2;
                default: skew_val <= 2'd0;
            endcase
        end else begin
            // mod-3 decrement
            case(skew_val)
                2'd2:    skew_val <= 2'd1;
                2'd1:    skew_val <= 2'd0;
                default: skew_val <= 2'd2;
            endcase
        end
    end
end


// ** state machine **

localparam  ST_INIT_CAL = 0,    // calibrate both IODs
            ST_INIT_RST = 1,    // reset both IODs
            ST_IDLE     = 2,    // waiting for IOD change or cal timer
            ST_CHANGE   = 3,    // change IOD setting
            ST_CAL      = 4,    // recalibrate slave IOD
            ST_RST      = 5,    // reset slave IOD
            ST_SKEW     = 6;    // change clock skew

reg  [2:0]      st;
reg  [2:0]      next_st;

reg             next_iod_rst_slave;
reg             next_iod_rst_master;
reg             next_iod_cal_slave;
reg             next_iod_cal_master;
reg             next_iod_en;
reg             next_iod_inc;
reg             next_skew_en;
reg             next_skew_inc;
reg             next_bitslip_mask;

// skew/calibrate delay counter
reg  [12:0]     cnt;
wire            cnt_max         = cnt[12];
reg             cnt_clear;

always @(posedge clk) begin
    if(rst_out || cnt_clear) begin
        cnt     <= 0;
    end else if(!cnt_max) begin
        cnt     <= cnt + 1;
    end
end

// next-state logic
wire            iod_busy_i      = (iod_busy || iod_cal_slave || iod_rst_slave || iod_en);

always @* begin

    next_st             = st;
    
    cnt_clear           = 1'b0;

    next_iod_rst_slave  = 1'b0;
    next_iod_rst_master = 1'b0;
    next_iod_cal_slave  = 1'b0;
    next_iod_cal_master = 1'b0;
    next_iod_en         = 1'b0;
    next_iod_inc        = 1'b0;
    next_skew_en        = 1'b0;
    next_skew_inc       = skew_inc;
    next_bitslip_mask   = bitslip_mask; // set by ST_SKEW; cleared by ST_IDLE

    // ** initial calibration **
    
    if(st == ST_INIT_CAL) begin
        if(!iod_busy_i && cnt_max) begin
            // IODs ready; calibrate them both
            cnt_clear           = 1'b1;
            next_iod_cal_slave  = 1'b1;
            next_iod_cal_master = 1'b1;
            next_st             = ST_INIT_RST;
        end
    end
    if(st == ST_INIT_RST) begin
        if(!iod_busy_i) begin
            // done calibrating; reset both IODs
            next_iod_rst_slave  = 1'b1;
            next_iod_rst_master = 1'b1;
            next_st             = ST_IDLE;
        end
    end

    // ** periodic recalibration **

    if(st == ST_IDLE) begin
        if(cnt_max) begin
            // time for periodic recalibration
            cnt_clear           = 1'b1;
            next_bitslip_mask   = 1'b0; // 1st periodic recalibration clears mask
            next_st             = ST_CAL;
        end
        if(pd_valid && ((pd_inc && !iod_val_max) || (!pd_inc && !iod_val_min)) ) begin
            // need to change IOD tap
            next_st             = ST_CHANGE;
        end
    end
    if(st == ST_CHANGE) begin
        if(!iod_busy_i) begin
            // change IOD tap
            next_iod_en         = 1'b1;
            next_iod_inc        = pd_inc; // relies on iserdes wrapper holding this value after pd_valid
            next_st             = disable_change_cal ? ST_RST : ST_CAL; // skip cal if disabled
        end
    end
    if(st == ST_CAL) begin
        if(!iod_busy_i) begin
            // tap change done (if performed); calibrate slave
            next_iod_cal_slave  = 1'b1;
            next_st             = ST_RST;
        end
    end
    if(st == ST_RST) begin
        if(!iod_busy_i) begin
            // calibration done; reset slave
            next_iod_rst_slave  = !disable_change_rst; // don't reset if disabled
            next_st             = ST_IDLE;
        end
    end

    // ** clock skew **

    if(st == ST_SKEW) begin
        // drive skew change request to oserdes
        next_skew_en        = !skew_ack;
        // bitslip mask will prevent errors being reported immediately after skew change
        // will be cleared once 1st periodic recalibration occurs after change
        next_bitslip_mask   = 1'b1;
        cnt_clear           = 1'b1;
        if(skew_ack) begin
            // skew change made; recalibrate everything
            next_st             = disable_skew_rst ? ST_IDLE : ST_INIT_CAL;
        end
    end

    // clock skew
    if( (frame_end || !interface_ready_pre) && !bitslip_mask && (
        ((iod_val_max || iod_val_min) && !disable_skew) || force_skew) )
    begin
        next_skew_inc       = force_skew ? 1'b1 : iod_val_max;
        next_st             = ST_SKEW;
    end

    // force recalibration
    if( force_rst && !(st == ST_INIT_CAL || st == ST_INIT_RST) ) begin
        cnt_clear           = 1'b1;
        next_st             = ST_INIT_CAL;
    end

end

// register state machine signals
always @(posedge clk) begin
    if(rst_out) begin
        st              <= ST_INIT_CAL;
        iod_rst_slave   <= 1'b1;
        iod_rst_master  <= 1'b1;
        iod_cal_slave   <= 1'b0;
        iod_cal_master  <= 1'b0;
        iod_en          <= 1'b0;
        iod_inc         <= 1'b0;
        skew_en         <= 1'b0;
        skew_inc        <= 1'b0;
        bitslip_mask    <= 1'b1;
    end else begin
        st              <= next_st;
        iod_rst_slave   <= next_iod_rst_slave;
        iod_rst_master  <= next_iod_rst_master;
        iod_cal_slave   <= next_iod_cal_slave;
        iod_cal_master  <= next_iod_cal_master;
        iod_en          <= next_iod_en;
        iod_inc         <= next_iod_inc;
        skew_en         <= next_skew_en;
        skew_inc        <= next_skew_inc;
        bitslip_mask    <= next_bitslip_mask;
    end
end

// create set_ signals
always @* begin

    set_serial_ready    = !serial_ready && bitslip_okay;

    set_interface_ready = 1'b0;
    set_output_ready    = 1'b0;

    if(frame_end && interface_ready_pre && !bitslip_error && !sync_error) begin
        set_interface_ready = !interface_ready;
        if(res_okay) begin
            set_output_ready    = !output_ready;
        end
    end

    set_skew_done       = bitslip_mask && !next_bitslip_mask;

end

// create status flags
always @(posedge clk) begin
    if(rst_out) begin

        serial_ready        <= 1'b0;
        interface_ready_pre <= 1'b0;
        interface_ready     <= 1'b0;
        output_ready        <= 1'b0;

    end else begin

        serial_ready        <= bitslip_okay;

        if(frame_end) begin
            interface_ready_pre <= 1'b1;
        end
        if(set_interface_ready) begin
            interface_ready     <= 1'b1;
        end
        if(set_output_ready) begin
            output_ready        <= 1'b1;
        end

        if(bitslip_error || sync_error) begin
            interface_ready_pre <= 1'b0;
            interface_ready     <= 1'b0;
        end
        if(bitslip_error || sync_error || res_error) begin
            output_ready        <= 1'b0;
        end

    end
end

endmodule

