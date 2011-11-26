
module dlsc_pcie_s6_registers #(
    parameter APB_CLK_DOMAIN    = 0,
    parameter APB_EN            = 1,                // enable APB registers and internal interrupts
    parameter APB_INT_EN        = APB_EN,           // enable outbound interrupts
    parameter APB_CONFIG_EN     = APB_EN,           // enable APB access to PCIe configuration space
    parameter APB_ADDR          = 32,               // width of APB address bus
    parameter AUTO_POWEROFF     = 1,                // automatically acknowledge power-off requests
    parameter INTERRUPTS        = 1,                // number of interrupt request inputs (1-32)
    parameter INT_ASYNC         = 1                 // re-synchronize interrupt inputs
) (
    // ** APB **
    
    // System
    input   wire                    apb_clk,
    input   wire                    apb_rst,

    // APB
    input   wire    [APB_ADDR-1:0]  apb_addr,
    input   wire                    apb_sel,
    input   wire                    apb_enable,
    input   wire                    apb_write,
    input   wire    [31:0]          apb_wdata,
    input   wire    [3:0]           apb_strb,
    output  reg                     apb_ready,
    output  reg     [31:0]          apb_rdata,
    output  reg                     apb_slverr,

    // Interrupts
    input   wire    [INTERRUPTS-1:0] apb_int_in,
    output  reg                     apb_int_out,

    // ** Outbound **
    
    // APB
    output  wire    [APB_ADDR-1:0]  apb_ob_addr,
    output  reg                     apb_ob_sel,
    output  wire                    apb_ob_enable,
    output  wire                    apb_ob_write,
    output  wire    [31:0]          apb_ob_wdata,
    output  wire    [3:0]           apb_ob_strb,
    input   wire                    apb_ob_ready,
    input   wire    [31:0]          apb_ob_rdata,
    
    // Control/Status
    output  reg                     apb_ob_rd_disable,
    output  reg                     apb_ob_wr_disable,
    input   wire                    apb_ob_rd_busy,
    input   wire                    apb_ob_wr_busy,

    // ** Inbound **
    
    // Control/Status
    output  reg                     apb_ib_rd_disable,
    output  reg                     apb_ib_wr_disable,
    input   wire                    apb_ib_rd_busy,
    input   wire                    apb_ib_wr_busy,

    // ** PCIe **

    // System
    input   wire                    pcie_clk,
    input   wire                    pcie_rst,
    
    // Common Interface
    input   wire                    pcie_user_lnk_up,

    // Configuration space read
    output  wire                    pcie_cfg_rd_en,
    output  wire    [9:0]           pcie_cfg_dwaddr,
    input   wire                    pcie_cfg_rd_wr_done,
    input   wire    [31:0]          pcie_cfg_do,

    // Configuration space values
    input   wire    [7:0]           pcie_cfg_bus_number,
    input   wire    [4:0]           pcie_cfg_device_number,
    input   wire    [2:0]           pcie_cfg_function_number,
    input   wire    [15:0]          pcie_cfg_status,
    input   wire    [15:0]          pcie_cfg_command,
    input   wire    [15:0]          pcie_cfg_dstatus,
    input   wire    [15:0]          pcie_cfg_dcommand,
    input   wire    [15:0]          pcie_cfg_lstatus,
    input   wire    [15:0]          pcie_cfg_lcommand,

    // Power management
    input   wire    [2:0]           pcie_cfg_pcie_link_state,
    input   wire                    pcie_cfg_to_turnoff,
    output  wire                    pcie_cfg_turnoff_ok,
    output  wire                    pcie_cfg_pm_wake,

    // Interrupts
    input   wire                    pcie_cfg_interrupt_msienable,
    input   wire    [2:0]           pcie_cfg_interrupt_mmenable,
    input   wire                    pcie_cfg_interrupt_rdy,
    output  wire                    pcie_cfg_interrupt,
    output  wire                    pcie_cfg_interrupt_assert,
    output  wire    [7:0]           pcie_cfg_interrupt_di
);

//
// Registers
//
// 0x0: control             (RW)
//      0       : inbound read disable
//      1       : inbound write disable
//      2       : outbound read disable
//      3       : outbound write disable
//      4       : ob interrupt disable
//      30      : pm_wake
//      31      : turnoff_ok
// 0x1: status              (RO)
//      0       : inbound read busy
//      1       : inbound write busy
//      2       : outbound read busy
//      3       : outbound write busy
//      28:24   : ltssm_state
//      31:29   : link_state
// 0x2: interrupt flags:    (RO)
//     cfg_dstatus:
//      0       : correctable error detected (cfg_dstatus[0])
//      1       : non-fatal error detected  (cfg_dstatus[1])
//      2       : fatal error detected       (cfg_dstatus[2])
//      3       : unsupported request detected (cfg_dstatus[3])
//     cfg_status/command:
//      8       : master data parity error  (cfg_status[8])
//      9       : bus master enable         (cfg_command[2])
//      10      : legacy interrupt enable   (!cfg_command[10])
//      11      : signaled target abort     (cfg_status[11])
//      12      : received target abort     (cfg_status[12])
//      13      : received master abort     (cfg_status[13])
//      14      : signaled system error     (cfg_status[14])
//      15      : detected parity error     (cfg_status[15])
//     link_state:
//      16      : link_up
//      17      : link_down
//      18      : link_state_transition
//      19      : link_state_l0
//      20      : link_state_l0s
//      21      : link_state_l1
//     misc:
//      30      : turnoff_req
//      31      : outbound_interrupt
// 0x3: interrupt select    (RW)
// 0x4: ob interrupt force  (RW)
// 0x5: ob interrupt flags  (RO)
// 0x6: ob interrupt select (RW)
// 0x7: ob interrupt ack    (WO)
//      0       : interrupt acknowledge
//
// 0x10-0x1F: outbound translator
//
// 0x400-0x7FF: PCIe config space
//

localparam  REG_CONTROL         = 3'h0,
            REG_STATUS          = 3'h1,
            REG_INT_FLAGS       = 3'h2,
            REG_INT_SELECT      = 3'h3,
            REG_OBINT_FORCE     = 3'h4,
            REG_OBINT_FLAGS     = 3'h5,
            REG_OBINT_SELECT    = 3'h6,
            REG_OBINT_ACK       = 3'h7;


// Synchronize PCIe reset

wire            apb_pcie_rst;

generate
if(APB_CLK_DOMAIN!=0) begin:GEN_RST_ASYNC
    // synchronize pcie_rst
    dlsc_syncflop #(
        .DATA           ( 1 ),
        .RESET          ( 1'b1 )
    ) dlsc_syncflop_pcie_rst (
        .in             ( pcie_rst ),
        .clk            ( apb_clk ),
        .rst            ( apb_rst ),
        .out            ( apb_pcie_rst )
    );
end else begin:GEN_RST_SYNC
    assign apb_pcie_rst = pcie_rst;
end
endgenerate


// APB bridge to PCIe config space

reg             apb_pcie_sel;
wire            apb_pcie_ready;
wire [31:0]     apb_pcie_rdata;

wire [11:2]     pcie_apb_addr;
wire            pcie_apb_sel;
wire            pcie_apb_enable;
wire            pcie_apb_write;
reg             pcie_apb_ready;
reg  [31:0]     pcie_apb_rdata;

generate

if(APB_CLK_DOMAIN!=0 && APB_CONFIG_EN!=0) begin:GEN_APB_CONFIG_ASYNC
    dlsc_apb_domaincross #(
        .DATA           ( 32 ),
        .ADDR           ( 10 )
    ) dlsc_apb_domaincross_trans (
        .in_clk         ( apb_clk ),
        .in_rst         ( apb_pcie_rst ),
        .in_addr        ( apb_addr[11:2] ),
        .in_sel         ( apb_pcie_sel ),
        .in_enable      ( apb_enable ),
        .in_write       ( apb_write ),
        .in_wdata       ( 32'd0 ),
        .in_strb        ( 4'd0 ),
        .in_ready       ( apb_pcie_ready ),
        .in_rdata       ( apb_pcie_rdata ),
        .in_slverr      (  ),
        .out_clk        ( pcie_clk ),
        .out_rst        ( pcie_rst ),
        .out_addr       ( pcie_apb_addr ),
        .out_sel        ( pcie_apb_sel ),
        .out_enable     ( pcie_apb_enable ),
        .out_write      ( pcie_apb_write ),
        .out_wdata      (  ),
        .out_strb       (  ),
        .out_ready      ( pcie_apb_ready ),
        .out_rdata      ( pcie_apb_rdata ),
        .out_slverr     ( 1'b0 )
    );
end else begin:GEN_APB_CONFIG_SYNC
    assign  pcie_apb_addr   = apb_addr[11:2];
    assign  pcie_apb_sel    = apb_pcie_sel;
    assign  pcie_apb_enable = apb_enable;
    assign  pcie_apb_write  = apb_write;
    assign  apb_pcie_ready  = pcie_apb_ready;
    assign  apb_pcie_rdata  = pcie_apb_rdata;
end

if(APB_CONFIG_EN!=0) begin:GEN_APB_CONFIG
    assign  pcie_cfg_rd_en  = pcie_apb_sel && !pcie_apb_enable;
    assign  pcie_cfg_dwaddr = pcie_apb_addr[11:2];
    always @(posedge pcie_clk) begin
        if(pcie_rst || pcie_apb_ready) begin
            pcie_apb_ready  <= 1'b0;
            pcie_apb_rdata  <= 32'd0;
        end else if(pcie_cfg_rd_wr_done)begin
            pcie_apb_ready  <= 1'b1;
            pcie_apb_rdata  <= pcie_cfg_do;
        end
    end
end else begin:GEN_NO_APB_CONFIG
    assign  pcie_cfg_rd_en  = 1'b0;
    assign  pcie_cfg_dwaddr = 10'd0;
    always @* begin
        pcie_apb_ready  = pcie_apb_sel && pcie_apb_enable;
        pcie_apb_rdata  = 32'd0;
    end
end

endgenerate


// APB decoding

reg             apb_csr_sel;
reg             apb_null_sel;

always @* begin
    apb_csr_sel     = 1'b0;
    apb_ob_sel      = 1'b0;
    apb_pcie_sel    = 1'b0;
    apb_null_sel    = 1'b0;

    if(apb_sel && !apb_ready) begin
        casez(apb_addr[12:2])
            11'b000_0000_0???: apb_csr_sel  = 1'b1;
            11'b000_0001_????: apb_ob_sel   = 1'b1;
            11'b1??_????_????: apb_pcie_sel = 1'b1;
            default:           apb_null_sel = 1'b1;
        endcase
    end
end

assign          apb_ob_addr     = apb_addr;
assign          apb_ob_enable   = apb_enable;
assign          apb_ob_write    = apb_write;
assign          apb_ob_wdata    = apb_wdata;
assign          apb_ob_strb     = apb_strb;

wire    [2:0]   csr_addr        = apb_addr[4:2];
wire    [31:0]  csr_wdata       = apb_wdata;
wire    [31:0]  csr_rd          = {32{(apb_csr_sel && !apb_enable && !apb_write)}};
wire    [31:0]  csr_wr          = {32{(apb_csr_sel && !apb_enable &&  apb_write)}} &
                                    { {8{apb_strb[3]}},{8{apb_strb[2]}},{8{apb_strb[1]}},{8{apb_strb[0]}} };


// ** synchronize PCIe status to APB domain **

wire [4:0]      pcie_cfg_ltssm_state = 5'd0; // TODO - S6 AXI PCIe core doesn't provide this

wire            link_up;
wire [4:0]      ltssm_state;
wire [2:0]      link_state;
wire            turnoff_req;
wire            err_correctable;        // cfg_dstatus[0]
wire            err_nonfatal;           // cfg_dstatus[1]
wire            err_fatal;              // cfg_dstatus[2]
wire            err_unsupported;        // cfg_dstatus[3]
wire            err_masterparity;       // cfg_status[8]
wire            bus_master_enable;      // cfg_command[2]
wire            legacy_int;             // !cfg_command[10]
wire            err_target_abort_tx;    // cfg_status[11]
wire            err_target_abort_rx;    // cfg_status[12]
wire            err_master_abort;       // cfg_status[13]
wire            err_system;             // cfg_status[14]
wire            err_parity;             // cfg_status[15]

generate
if(APB_CLK_DOMAIN!=0) begin:GEN_STATUS_ASYNC
    dlsc_domaincross #(
        .DATA ( 1+5+3+1+12 )
    ) dlsc_domaincross_pcie_status (
        .in_clk     ( pcie_clk ),
        .in_rst     ( pcie_rst ),
        .in_data    ( {
            pcie_user_lnk_up,
            pcie_cfg_ltssm_state,
            pcie_cfg_pcie_link_state,
            pcie_cfg_to_turnoff,
            pcie_cfg_dstatus[0],
            pcie_cfg_dstatus[1],
            pcie_cfg_dstatus[2],
            pcie_cfg_dstatus[3],
            pcie_cfg_status[8],
            pcie_cfg_command[2],
            !pcie_cfg_command[10],
            pcie_cfg_status[11],
            pcie_cfg_status[12],
            pcie_cfg_status[13],
            pcie_cfg_status[14],
            pcie_cfg_status[15] } ),
        .out_clk    ( apb_clk ),
        .out_rst    ( apb_pcie_rst ),
        .out_data   ( {
            link_up,
            ltssm_state,
            link_state,
            turnoff_req,
            err_correctable,
            err_nonfatal,
            err_fatal,
            err_unsupported,
            err_masterparity,
            bus_master_enable,
            legacy_int,
            err_target_abort_tx,
            err_target_abort_rx,
            err_master_abort,
            err_system,
            err_parity } )
    );
end else begin:GEN_STATUS_SYNC
    assign link_up              = pcie_user_lnk_up;
    assign ltssm_state          = pcie_cfg_ltssm_state;
    assign link_state           = pcie_cfg_pcie_link_state;
    assign turnoff_req          = pcie_cfg_to_turnoff;
    assign err_correctable      = pcie_cfg_dstatus[0];
    assign err_nonfatal         = pcie_cfg_dstatus[1];
    assign err_fatal            = pcie_cfg_dstatus[2];
    assign err_unsupported      = pcie_cfg_dstatus[3];
    assign err_masterparity     = pcie_cfg_status[8];
    assign bus_master_enable    = pcie_cfg_command[2];
    assign legacy_int           = !pcie_cfg_command[10];
    assign err_target_abort_tx  = pcie_cfg_status[11];
    assign err_target_abort_rx  = pcie_cfg_status[12];
    assign err_master_abort     = pcie_cfg_status[13];
    assign err_system           = pcie_cfg_status[14];
    assign err_parity           = pcie_cfg_status[15];
end
endgenerate


// decode link_state

wire            link_down = !link_up;
reg             link_state_transition;
reg             link_state_l0;
reg             link_state_l0s;
reg             link_state_l1;

always @* begin
    link_state_transition   = 1'b0;
    link_state_l0           = 1'b0;
    link_state_l0s          = 1'b0;
    link_state_l1           = 1'b0;
    if(link_up) begin
        case(link_state)
            3'b110:  link_state_l0          = 1'b1;
            3'b101:  link_state_l0s         = 1'b1;
            3'b011:  link_state_l1          = 1'b1;
            3'b111:  link_state_transition  = 1'b1;
            default: link_state_transition  = 1'b1;
        endcase
    end
end


// ** control register **

reg         apb_int_disable;
reg         apb_pm_wake;
reg         apb_turnoff_ok;

// write control (for bits reset by pcie_rst)

wire        apb_pm_wake_ack;

always @(posedge apb_clk) begin
    if(apb_pcie_rst) begin
        apb_pm_wake     <= 1'b0;
        apb_turnoff_ok  <= AUTO_POWEROFF;
    end else begin
        if(apb_pm_wake_ack) begin
            apb_pm_wake     <= 1'b0;
        end
        if(csr_addr == REG_CONTROL) begin
            if(csr_wr[30] && csr_wdata[30]) begin
                apb_pm_wake     <= 1'b1;
            end
            if(csr_wr[31]) begin
                apb_turnoff_ok  <= csr_wdata[31];
            end
        end
    end
end

// write control (for bits reset by apb_rst)

always @(posedge apb_clk) begin
    if(apb_rst) begin
        apb_ib_rd_disable       <= 1'b0;
        apb_ib_wr_disable       <= 1'b0;
        apb_ob_rd_disable       <= 1'b0;    // TODO parameterize default state
        apb_ob_wr_disable       <= 1'b0;
        apb_int_disable         <= 1'b0;
    end else if(csr_addr == REG_CONTROL) begin
        if(csr_wr[0]) apb_ib_rd_disable <= csr_wdata[0];
        if(csr_wr[1]) apb_ib_wr_disable <= csr_wdata[1];
        if(csr_wr[2]) apb_ob_rd_disable <= csr_wdata[2];
        if(csr_wr[3]) apb_ob_wr_disable <= csr_wdata[3];
        if(csr_wr[4]) apb_int_disable   <= csr_wdata[4];
    end
end

// read control

reg  [31:0] csr_control;

always @* begin
    csr_control     = 0;
    csr_control[0]  = apb_ib_rd_disable;
    csr_control[1]  = apb_ib_wr_disable;
    csr_control[2]  = apb_ob_rd_disable;
    csr_control[3]  = apb_ob_wr_disable;
    csr_control[4]  = apb_int_disable;
    csr_control[30] = 1'b0;                 // apb_pm_wake is self-clearing
    csr_control[31] = apb_turnoff_ok;
end

// connect control to PCIe domain

wire        pcie_pm_wake_valid;
wire        pcie_pm_wake_ready;

assign      pcie_pm_wake_ready  = (pcie_cfg_pcie_link_state != 3'b111); // can't issue wake when link is "in transition"
assign      pcie_cfg_pm_wake    = pcie_pm_wake_ready && pcie_pm_wake_valid;

generate
if(APB_CLK_DOMAIN!=0) begin:GEN_REG_CONTROL_ASYNC
    dlsc_domaincross_rvh #(
        .DATA           ( 1 ),
        .RESET          ( 1'b0 )
    ) dlsc_domaincross_rvh_pm_wake (
        .in_clk         ( apb_clk ),
        .in_rst         ( apb_pcie_rst ),
        .in_ready       (  ),
        .in_valid       ( apb_pm_wake ),
        .in_data        ( 1'b0 ),
        .out_clk        ( pcie_clk ),
        .out_rst        ( pcie_rst ),
        .out_ready      ( pcie_pm_wake_ready ),
        .out_valid      ( pcie_pm_wake_valid ),
        .out_data       (  )
    );
    dlsc_syncflop #(
        .DATA           ( 1 ),
        .RESET          ( 1'b0 )
    ) dlsc_syncflop_turnoff_ok (
        .in             ( apb_turnoff_ok ),
        .clk            ( pcie_clk ),
        .rst            ( pcie_rst ),
        .out            ( pcie_cfg_turnoff_ok )
    );
    assign  apb_pm_wake_ack         = 1'b1;
end else begin:GEN_REG_CONTROL_SYNC
    assign  apb_pm_wake_ack         = pcie_pm_wake_ready;
    assign  pcie_pm_wake_valid      = apb_pm_wake;
    assign  pcie_cfg_turnoff_ok     = apb_turnoff_ok;
end
endgenerate


// ** status register **

reg  [31:0] csr_status;

always @* begin
    csr_status          = 0;
    csr_status[0]       = apb_ib_rd_busy;
    csr_status[1]       = apb_ib_wr_busy;
    csr_status[2]       = apb_ob_rd_busy;
    csr_status[3]       = apb_ob_wr_busy;
    csr_status[28:24]   = ltssm_state;
    csr_status[31:29]   = link_state;
end


// ** interrupt flags **

reg         apb_int_ob          = 1'b0;

reg  [31:0] csr_int_flags;

always @* begin
    csr_int_flags       = 0;
    csr_int_flags[0]    = err_correctable;
    csr_int_flags[1]    = err_nonfatal;
    csr_int_flags[2]    = err_fatal;
    csr_int_flags[3]    = err_unsupported;
    csr_int_flags[8]    = err_masterparity;
    csr_int_flags[9]    = bus_master_enable;
    csr_int_flags[10]   = legacy_int;
    csr_int_flags[11]   = err_target_abort_tx;
    csr_int_flags[12]   = err_target_abort_rx;
    csr_int_flags[13]   = err_master_abort;
    csr_int_flags[14]   = err_system;
    csr_int_flags[15]   = err_parity;
    csr_int_flags[16]   = link_up;
    csr_int_flags[17]   = link_down;
    csr_int_flags[18]   = link_state_transition;
    csr_int_flags[19]   = link_state_l0;
    csr_int_flags[20]   = link_state_l0s;
    csr_int_flags[21]   = link_state_l1;
    csr_int_flags[22]   = turnoff_req;
    csr_int_flags[31]   = apb_int_ob;
end


// ** interrupt select **

reg  [31:0] csr_int_select;

always @(posedge apb_clk) begin
    if(apb_rst) begin
        csr_int_select  <= 0;
    end else if(csr_addr == REG_INT_SELECT) begin
        if(csr_wr[ 0]) csr_int_select[ 0] <= csr_wdata[ 0];
        if(csr_wr[ 1]) csr_int_select[ 1] <= csr_wdata[ 1];
        if(csr_wr[ 2]) csr_int_select[ 2] <= csr_wdata[ 2];
        if(csr_wr[ 3]) csr_int_select[ 3] <= csr_wdata[ 3];
        if(csr_wr[ 8]) csr_int_select[ 8] <= csr_wdata[ 8];
        if(csr_wr[ 9]) csr_int_select[ 9] <= csr_wdata[ 9];
        if(csr_wr[10]) csr_int_select[10] <= csr_wdata[10];
        if(csr_wr[11]) csr_int_select[11] <= csr_wdata[11];
        if(csr_wr[12]) csr_int_select[12] <= csr_wdata[12];
        if(csr_wr[13]) csr_int_select[13] <= csr_wdata[13];
        if(csr_wr[14]) csr_int_select[14] <= csr_wdata[14];
        if(csr_wr[15]) csr_int_select[15] <= csr_wdata[15];
        if(csr_wr[16]) csr_int_select[16] <= csr_wdata[16];
        if(csr_wr[17]) csr_int_select[17] <= csr_wdata[17];
        if(csr_wr[18]) csr_int_select[18] <= csr_wdata[18];
        if(csr_wr[19]) csr_int_select[19] <= csr_wdata[19];
        if(csr_wr[20]) csr_int_select[20] <= csr_wdata[20];
        if(csr_wr[21]) csr_int_select[21] <= csr_wdata[21];
        if(csr_wr[22]) csr_int_select[22] <= csr_wdata[22];
        if(csr_wr[31]) csr_int_select[31] <= csr_wdata[31];
    end
end

always @(posedge apb_clk) begin
    if(apb_rst) begin
        apb_int_out <= 1'b0;
    end else begin
        apb_int_out <= |(csr_int_flags & csr_int_select);
    end
end


// ** outbound interrupts **

wire [31:0] csr_ob_int_flags;

reg  [31:0] csr_ob_int_force    = 32'd0;
reg  [31:0] csr_ob_int_select   = 32'd0;

integer i;

generate
if(APB_INT_EN) begin:GEN_OB_INT

    if(INTERRUPTS<32) begin:GEN_OB_INT_TIEOFF
        assign csr_ob_int_flags[31:INTERRUPTS] = 0;
    end

    if(INT_ASYNC) begin:GEN_OB_INT_ASYNC
        dlsc_syncflop #(
            .DATA       ( INTERRUPTS )
        ) dlsc_syncflop_int_in (
            .in         ( apb_int_in ),
            .clk        ( apb_clk ),
            .rst        ( apb_rst ),
            .out        ( csr_ob_int_flags[INTERRUPTS-1:0] )
        );
    end else begin:GEN_OB_INT_SYNC
        assign csr_ob_int_flags[INTERRUPTS-1:0] = apb_int_in;
    end

    always @(posedge apb_clk) begin
        apb_int_ob  <= |(((csr_ob_int_flags|csr_ob_int_force)) & csr_ob_int_select);
    end

    always @(posedge apb_clk) begin
        if(apb_rst) begin
            csr_ob_int_force    <= 32'd0;
            csr_ob_int_select   <= 32'd0;
        end else begin
            if(csr_addr == REG_OBINT_FORCE) begin
                for(i=0;i<INTERRUPTS;i=i+1) begin
                    if(csr_wr[i]) csr_ob_int_force[i] <= csr_wdata[i];
                end
            end
            if(csr_addr == REG_OBINT_SELECT) begin
                for(i=0;i<INTERRUPTS;i=i+1) begin
                    if(csr_wr[i]) csr_ob_int_select[i] <= csr_wdata[i];
                end
            end
        end
    end

    reg     apb_int_redo;

    always @(posedge apb_clk) begin
        apb_int_redo    <= 1'b0;
        if(csr_addr == REG_OBINT_ACK && csr_wr[0] && csr_wdata[0]) begin
            apb_int_redo    <= 1'b1;
        end
    end

    dlsc_pcie_s6_interrupts #(
        .APB_CLK_DOMAIN                 ( APB_CLK_DOMAIN )
    ) dlsc_pcie_s6_interrupts_inst (
        .apb_clk                        ( apb_clk ),
        .apb_rst                        ( apb_rst ),
        .apb_pcie_rst                   ( apb_pcie_rst ),
        .apb_int_ob                     ( apb_int_ob && !apb_int_disable ),
        .apb_int_redo                   ( apb_int_redo ),
        .pcie_clk                       ( pcie_clk ),
        .pcie_rst                       ( pcie_rst ),
        .pcie_cfg_interrupt_msienable   ( pcie_cfg_interrupt_msienable ),
        .pcie_cfg_interrupt_mmenable    ( pcie_cfg_interrupt_mmenable ),
        .pcie_cfg_interrupt_rdy         ( pcie_cfg_interrupt_rdy ),
        .pcie_cfg_interrupt             ( pcie_cfg_interrupt ),
        .pcie_cfg_interrupt_assert      ( pcie_cfg_interrupt_assert ),
        .pcie_cfg_interrupt_di          ( pcie_cfg_interrupt_di )
    );

end else begin:GEN_NO_OB_INT

    assign  csr_ob_int_flags            = 32'd0;

    assign  pcie_cfg_interrupt          = 1'b0;
    assign  pcie_cfg_interrupt_assert   = 1'b0;
    assign  pcie_cfg_interrupt_di       = 8'd0;

end
endgenerate


// ** APB response **

always @(posedge apb_clk) begin
    if(apb_rst||apb_ready) begin
        apb_ready       <= 1'b0;
        apb_rdata       <= 0;
        apb_slverr      <= 1'b0;
    end else begin
        if(apb_csr_sel) begin
            apb_ready       <= 1'b1;
            apb_slverr      <= 1'b0;
            case(csr_addr)
                REG_CONTROL:        apb_rdata <= csr_control;
                REG_STATUS:         apb_rdata <= csr_status;
                REG_INT_FLAGS:      apb_rdata <= csr_int_flags;
                REG_INT_SELECT:     apb_rdata <= csr_int_select;
                REG_OBINT_FORCE:    apb_rdata <= csr_ob_int_force;
                REG_OBINT_FLAGS:    apb_rdata <= csr_ob_int_flags;
                REG_OBINT_SELECT:   apb_rdata <= csr_ob_int_select;
                REG_OBINT_ACK:      apb_rdata <= 0;
                default:            apb_rdata <= 0;
            endcase
        end
        if(apb_ob_sel) begin
            apb_ready       <= apb_ob_ready;
            apb_slverr      <= 1'b0;
            apb_rdata       <= apb_ob_rdata;
        end
        if(apb_pcie_sel) begin
            apb_ready       <= apb_pcie_ready;
            apb_slverr      <= 1'b0;
            apb_rdata       <= apb_pcie_rdata;
        end
        if(apb_null_sel) begin
            apb_ready       <= 1'b1;
            apb_slverr      <= 1'b0;
            apb_rdata       <= 0;
        end
    end
end


endmodule

