
module dlsc_dcm_clkgen #(
    // APB
    parameter ADDR              = 32,
    parameter ENABLE            = 0,        // default to enabled state
    // DCM defaults
    parameter CLK_IN_PERIOD     = 5.0,      // clk_in period in ns
    parameter CLK_DIVIDE        = 1,        // divide value D (1-256)
    parameter CLK_MULTIPLY      = 4,        // multiply value M (2-256)
    parameter CLK_MD_MAX        = 4.0,      // maximum programmable M/D ratio
    parameter CLK_DIV_DIVIDE    = 2         // clk_div = clk/CLK_DIV_DIVIDE (2, 4, 8, 16, 32)
) (
    // APB bus
    input   wire                    apb_clk,
    input   wire                    apb_rst,
    input   wire    [ADDR-1:0]      apb_addr,
    input   wire                    apb_sel,
    input   wire                    apb_enable,
    input   wire                    apb_write,
    input   wire    [31:0]          apb_wdata,
    input   wire    [3:0]           apb_strb,
    output  reg                     apb_ready,
    output  reg     [31:0]          apb_rdata,

    // Interrupt
    output  reg                     apb_int_out,

    // DCM input
    input   wire                    clk_in,     // CLKIN
    input   wire                    rst_in,

    // DCM output
    output  wire                    clk,        // CLKFX
    output  wire                    clk_n,      // CLKFX180
    output  wire                    clk_div,    // CLKFXDV
    output  wire                    rst         // synced to clk
);

// ** registers **

localparam  REG_CONTROL     = 3'h0,
            REG_STATUS      = 3'h1,
            REG_INT_FLAGS   = 3'h2,
            REG_INT_SELECT  = 3'h3,
            REG_MULTIPLY    = 3'h4,
            REG_DIVIDE      = 3'h5;

// 0x0: control (RW)
//  [0]     : enable
//  [1]     : use default M/D values
//  [2]     : ignore DCM stopped status
// 0x1: status (RO)
//  [0]     : ready
//  [1]     : int_out
//  [2]     : rst_in
//  [3]     : rst_out
//  [4]     : dcm_rst
//  [5]     : dcm_locked
//  [6]     : dcm_stopped
//  [7]     : dcm_ready
//  [8]     : prog_done
//  [14:12] : controller state
// 0x2: interrupt flags (RW; write 1 to clear)
//  [0]     : enabled
//  [1]     : disabled
// 0x3: interrupt select (RW)
// 0x4: multiply (RW; only writeable when disabled)
//  [7:0]   : M-1 (0-255)
// 0x5: divide (RW; only writeable when disabled)
//  [7:0]   : D-1 (1-255)

wire    [2:0]   csr_addr        = apb_addr[4:2];
wire    [31:0]  csr_wdata       = apb_wdata;
wire    [31:0]  csr_rd          = {32{(apb_sel && !apb_enable && !apb_write)}};
wire    [31:0]  csr_wr          = {32{(apb_sel && !apb_enable &&  apb_write)}} &
                                    { {8{apb_strb[3]}},{8{apb_strb[2]}},{8{apb_strb[1]}},{8{apb_strb[0]}} };

wire            obs_rst_in;
wire            obs_out_rst;    // rst output synchronized to apb_clk domain
reg             obs_out_rst_prev;

always @(posedge apb_clk) begin
    obs_out_rst_prev <= obs_out_rst;
end

// control/status

wire            obs_dcm_rst;
wire            obs_dcm_locked;
wire            obs_dcm_stopped;
wire            obs_dcm_ready;
reg             prog_done_r;
reg  [3:0]      st;

reg             ctrl_enable;
reg             use_defaults;
reg             ignore_stopped;
reg             status_ready;

wire [31:0]     csr_control     = { 29'd0, ignore_stopped, use_defaults, ctrl_enable };

wire [31:0]     csr_status;
assign          csr_status[31:16]   = 0;
assign          csr_status[15:12]   = { 1'b0, st};
assign          csr_status[11:0]    = { 1'b0,           1'b0,           1'b0,           prog_done_r,
                                        obs_dcm_ready,  obs_dcm_stopped,obs_dcm_locked, obs_dcm_rst,
                                        obs_out_rst,    obs_rst_in,     apb_int_out,    status_ready };

wire            set_enabled     = (!obs_out_rst &&  obs_out_rst_prev);
wire            set_disabled    = ( obs_out_rst && !obs_out_rst_prev) || (ctrl_enable && obs_rst_in);

always @(posedge apb_clk) begin
    if(apb_rst) begin
        ctrl_enable     <= ENABLE;
        use_defaults    <= ENABLE;
        ignore_stopped  <= 1'b0;
        status_ready    <= 1'b0;
    end else begin
        if(csr_addr == REG_CONTROL) begin
            if(csr_wr[0]) ctrl_enable       <= csr_wdata[0];
            if(csr_wr[1]) use_defaults      <= csr_wdata[1];
            if(csr_wr[2]) ignore_stopped    <= csr_wdata[2];
        end
        if(set_enabled) begin
            status_ready    <= 1'b1;
        end
        if(set_disabled) begin
            ctrl_enable     <= 1'b0;
            status_ready    <= 1'b0;
        end
    end
end

// interrupts

reg  [1:0]      int_flags;
reg  [1:0]      int_select;

always @(posedge apb_clk) begin
    if(apb_rst) begin
        int_flags       <= 0;
        int_select      <= 0;
        apb_int_out     <= 1'b0;
    end else begin
        
        if(csr_addr == REG_INT_FLAGS) begin
            // clear flags when written with a 1
            int_flags       <= int_flags & ~(csr_wr[1:0] & csr_wdata[1:0]);
        end
        if(csr_addr == REG_INT_SELECT) begin
            int_select      <= (int_select & ~csr_wr[1:0]) | (csr_wdata[1:0] & csr_wr[1:0]);
        end

        if(set_enabled) begin
            int_flags[0]    <= 1'b1;
        end
        if(set_disabled) begin
            int_flags[1]    <= 1'b1;
        end

        apb_int_out     <= |(int_flags & int_select);

    end
end

// multiply/divide

reg  [7:0]      mult;
reg  [7:0]      div;

always @(posedge apb_clk) begin
    if(apb_rst) begin
/* verilator lint_off WIDTH */
        mult            <= CLK_MULTIPLY-1;
        div             <= CLK_DIVIDE-1;
/* verilator lint_on WIDTH */
    end else if(!ctrl_enable) begin
        if(csr_addr == REG_MULTIPLY) begin
            mult            <= (mult & ~csr_wr[7:0]) | (csr_wdata[7:0] & csr_wr[7:0]);
        end
        if(csr_addr == REG_DIVIDE) begin
            div             <= (div  & ~csr_wr[7:0]) | (csr_wdata[7:0] & csr_wr[7:0]);
        end
    end
end

// register read

always @(posedge apb_clk) begin
    apb_ready       <= (apb_sel && !apb_enable);
    apb_rdata       <= 32'd0;
    if(apb_sel && !apb_enable && !apb_write) begin
        case(csr_addr)
            REG_CONTROL:        apb_rdata       <= csr_control;
            REG_STATUS:         apb_rdata       <= csr_status;
            REG_INT_FLAGS:      apb_rdata[1:0]  <= int_flags;
            REG_INT_SELECT:     apb_rdata[1:0]  <= int_select;
            REG_MULTIPLY:       apb_rdata[7:0]  <= mult;
            REG_DIVIDE:         apb_rdata[7:0]  <= div;
            default:            apb_rdata       <= 0;
        endcase
    end
end

// ** clock buffers **

(* KEEP = "TRUE" *) wire clk_pre;
(* KEEP = "TRUE" *) wire clk_n_pre;
(* KEEP = "TRUE" *) wire clk_div_pre;

BUFG BUFG_clk (
    .I ( clk_pre ),
    .O ( clk )
);

BUFG BUFG_clk_n (
    .I ( clk_n_pre ),
    .O ( clk_n )
);

BUFG BUFG_clk_div (
    .I ( clk_div_pre ),
    .O ( clk_div )
);

// ** DCM **

wire        dcm_rst;
wire        dcm_locked;
wire [2:1]  dcm_status;
wire        dcm_stopped         = dcm_status[2];

reg         prog_en;
reg         prog_data;
wire        prog_done;

DCM_CLKGEN #(
    .CLKFXDV_DIVIDE     ( CLK_DIV_DIVIDE ),     // CLKFXDV divide value (2, 4, 8, 16, 32)
    .CLKFX_DIVIDE       ( CLK_DIVIDE ),         // Divide value - D - (1-256)
    .CLKFX_MD_MAX       ( CLK_MD_MAX ),         // Specify maximum M/D ratio for timing anlysis
    .CLKFX_MULTIPLY     ( CLK_MULTIPLY ),       // Multiply value - M - (2-256)
    .CLKIN_PERIOD       ( CLK_IN_PERIOD ),      // Input clock period specified in nS
    .SPREAD_SPECTRUM    ( "NONE" ),             // Spread Spectrum mode "NONE", "CENTER_LOW_SPREAD", "CENTER_HIGH_SPREAD",
                                                // "VIDEO_LINK_M0", "VIDEO_LINK_M1" or "VIDEO_LINK_M2" 
    .STARTUP_WAIT       ( "FALSE" )             // Delay config DONE until DCM_CLKGEN LOCKED (TRUE/FALSE)
) DCM_CLKGEN_inst (
    .CLKFX              ( clk_pre ),            // 1-bit output: Generated clock output
    .CLKFX180           ( clk_n_pre ),          // 1-bit output: Generated clock output 180 degree out of phase from CLKFX.
    .CLKFXDV            ( clk_div_pre ),        // 1-bit output: Divided clock output
    .LOCKED             ( dcm_locked ),         // 1-bit output: Locked output
    .PROGDONE           ( prog_done ),          // 1-bit output: Active high output to indicate the successful re-programming
    .STATUS             ( dcm_status ),         // 2-bit output: DCM_CLKGEN status
    .CLKIN              ( clk_in ),             // 1-bit input: Input clock
    .FREEZEDCM          ( 1'b0 ),               // 1-bit input: Prevents frequency adjustments to input clock
    .PROGCLK            ( apb_clk ),            // 1-bit input: Clock input for M/D reconfiguration
    .PROGDATA           ( prog_data ),          // 1-bit input: Serial data input for M/D reconfiguration
    .PROGEN             ( prog_en ),            // 1-bit input: Active high program enable
    .RST                ( dcm_rst )             // 1-bit input: Reset input pin
);

// ** sync **

dlsc_syncflop #(
    .DATA       ( 5 ),
    .RESET      ( 5'b11110 )
) dlsc_syncflop_obs (
    .in         ( {     rst_in,         rst,     dcm_rst,     dcm_stopped,    dcm_locked } ),
    .clk        ( apb_clk ),
    .rst        ( apb_rst ),
    .out        ( { obs_rst_in, obs_out_rst, obs_dcm_rst, obs_dcm_stopped, obs_dcm_locked } )
);

assign          obs_dcm_ready   = !obs_dcm_rst && obs_dcm_locked && (!obs_dcm_stopped || ignore_stopped);

reg             apb_dcm_rst;
assign          dcm_rst         = rst_in || apb_dcm_rst;

reg             apb_out_rst;
wire            out_rst         = rst_in || apb_out_rst;

dlsc_rstsync #(
    .DOMAINS    ( 1 )
) dlsc_rstsync_out (
    .rst_in     ( out_rst ),
    .clk        ( clk ),
    .rst_out    ( rst )
);

always @(posedge apb_clk) begin
    if(apb_rst) begin
        prog_done_r <= 1'b0;
    end else begin
        prog_done_r <= prog_done;
    end
end

// ** control **

localparam  ST_DISABLED     = 0,    // DCM disabled and held in reset
            ST_RELEASE      = 1,    // DCM releasing from reset
            ST_LOADD        = 2,    // loading divide value
            ST_LOADD_POST   = 3,    // waiting after loadd
            ST_LOADM        = 4,    // loading multiply value
            ST_LOADM_POST   = 5,    // waiting after loadm
            ST_GO           = 6,    // loading go command
            ST_WAIT         = 7,    // wait for lock
            ST_LOCKED       = 8,    // DCM ready; remove downstream reset
            ST_DISABLE      = 9;    // shutting down DCM; apply downstream reset

reg  [3:0]      next_st;

reg  [3:0]      cnt;
wire            cnt_max         = &cnt;
reg             cnt_clear;

always @(posedge apb_clk) begin
    if(cnt_clear) begin
        cnt     <= 0;
    end else begin
        cnt     <= cnt + 4'd1;
    end
end

wire [9:0]      loadd           = {  div, 2'b01 };
wire [9:0]      loadm           = { mult, 2'b11 };

wire            next_apb_dcm_rst = (st == ST_DISABLED);
wire            next_apb_out_rst = (st != ST_LOCKED);

reg             next_prog_en;
reg             next_prog_data;

always @* begin

    next_st         = st;
    cnt_clear       = 1'b1;

    next_prog_en    = 1'b0;
    next_prog_data  = 1'b0;

    if(st == ST_DISABLED) begin
        if(ctrl_enable && obs_dcm_rst) begin
            // DCM must be in reset before exiting this state
            next_st         = ST_RELEASE;
        end
    end
    if(st == ST_RELEASE) begin
        if(prog_done_r && !obs_dcm_rst) begin
            cnt_clear       = 1'b0;
            if(cnt_max) begin
                next_st         = use_defaults ? ST_WAIT : ST_LOADD;
            end
        end
    end
    if(st == ST_LOADD) begin
        cnt_clear       = 1'b0;
        next_prog_en    = 1'b1;
        next_prog_data  = loadd[cnt];
        if(cnt == 9) begin
            next_st         = ST_LOADD_POST;
        end
    end
    if(st == ST_LOADD_POST) begin
        cnt_clear       = 1'b0;
        if(cnt_max) begin
            next_st         = ST_LOADM;
        end
    end
    if(st == ST_LOADM) begin
        cnt_clear       = 1'b0;
        next_prog_en    = 1'b1;
        next_prog_data  = loadm[cnt];
        if(cnt == 9) begin
            next_st         = ST_LOADM_POST;
        end
    end
    if(st == ST_LOADM_POST) begin
        cnt_clear       = 1'b0;
        if(cnt_max) begin
            next_st         = ST_GO;
        end
    end
    if(st == ST_GO) begin
        next_prog_en    = 1'b1;
        next_prog_data  = 1'b0;
        next_st         = ST_WAIT;
    end
    if(st == ST_WAIT) begin
        if(prog_done_r && obs_dcm_ready) begin
            cnt_clear       = 1'b0;
            if(cnt_max) begin
                next_st         = ST_LOCKED;
            end
        end
    end
    if(st == ST_LOCKED) begin
        if(!ctrl_enable) begin
            // disable requested
            next_st         = ST_DISABLE;
        end
        if(!obs_dcm_ready) begin
            // lost lock
            next_st         = ST_DISABLED;
        end
    end
    if(st == ST_DISABLE) begin
        if(obs_out_rst) begin
            cnt_clear       = 1'b0;
            if(cnt_max) begin
                next_st         = ST_DISABLED;
            end
        end
    end

    if(!ctrl_enable && !(st == ST_LOCKED || st == ST_DISABLE)) begin
        // disabled before LOCKED; go straight to DISABLED
        next_st         = ST_DISABLED;
    end

    if(obs_dcm_rst && !(st == ST_DISABLED || st == ST_RELEASE)) begin
        // externally reset
        next_st         = ST_DISABLED;
    end

end

always @(posedge apb_clk) begin
    if(apb_rst) begin
        st          <= ST_DISABLED;
        prog_en     <= 1'b0;
        prog_data   <= 1'b0;
        apb_dcm_rst <= 1'b1;
        apb_out_rst <= 1'b1;
    end else begin
        st          <= next_st;
        prog_en     <= next_prog_en;
        prog_data   <= next_prog_data;
        apb_dcm_rst <= next_apb_dcm_rst;
        apb_out_rst <= next_apb_out_rst;
    end
end

// ** simulation checks **

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

reg ctrl_enable_prev;
real m;
real d;
always @(posedge apb_clk) begin
    if(ctrl_enable && !ctrl_enable_prev) begin
        if(mult == 0) begin
            `dlsc_error("REG_INT_MULTIPLY must be >= 1");
        end
        m = (mult*1.0) + 1.0;
        d = (div*1.0) + 1.0;
        if( (m/d) > CLK_MD_MAX ) begin
            `dlsc_error("M/D ratio exceeds CLK_MD_MAX");
        end
    end
    ctrl_enable_prev = ctrl_enable;
end

always @(posedge apb_clk) if(!apb_rst) begin
    if(apb_sel && apb_write && !apb_enable && ctrl_enable && (csr_addr == REG_MULTIPLY || csr_addr == REG_DIVIDE)) begin
        `dlsc_info("ignored write to register 0x%0x when ctrl_enable asserted", apb_addr[4:2]);
    end
end

`include "dlsc_sim_bot.vh"
`endif

endmodule

