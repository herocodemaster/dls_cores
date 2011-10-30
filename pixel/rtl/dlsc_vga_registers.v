
module dlsc_vga_registers #(
    parameter APB_ADDR          = 32,
    parameter AXI_ADDR          = 32,
    parameter BLEN              = 12,
    parameter XBITS             = 12,
    parameter YBITS             = 12,

    // modeline defaults
    // (640x480 @ 60 Hz; requires 24 MHz px_clk)
    parameter HDISP             = 640,
    parameter HSYNCSTART        = 672,
    parameter HSYNCEND          = 760,
    parameter HTOTAL            = 792,
    parameter VDISP             = 480,
    parameter VSYNCSTART        = 490,
    parameter VSYNCEND          = 495,
    parameter VTOTAL            = 505,

    // pixel defaults
    parameter BYTES_PER_PIXEL   = 3,
    parameter RED_POS           = 2,
    parameter GREEN_POS         = 1,
    parameter BLUE_POS          = 0,
    parameter ALPHA_POS         = 3,

    // buffer defaults
    parameter BYTES_PER_ROW     = HDISP*BYTES_PER_PIXEL,
    parameter ROW_STEP          = BYTES_PER_ROW,
    
    // prevent override of defaults
    parameter FIXED_MODELINE    = 0,
    parameter FIXED_PIXEL       = 0

) (
    // ** Bus Domain **

    // System
    input   wire                    clk,
    input   wire                    rst_in,
    output  wire                    rst_bus,
    output  wire                    rst_drv,

    // APB register bus
    input   wire    [APB_ADDR-1:0]  apb_addr,
    input   wire                    apb_sel,
    input   wire                    apb_enable,
    input   wire                    apb_write,
    input   wire    [31:0]          apb_wdata,
    input   wire    [3:0]           apb_strb,
    output  reg                     apb_ready,
    output  reg     [31:0]          apb_rdata,

    // Interrupt
    output  reg                     int_out,

    // Config/status to/from AXI reader
    output  reg                     axi_halt,
    input   wire                    axi_busy,
    input   wire                    axi_error,

    // Command to AXI reader
    input   wire                    axi_cmd_ready,
    output  wire                    axi_cmd_valid,
    output  wire    [AXI_ADDR-1:0]  axi_cmd_addr,
    output  wire    [BLEN-1:0]      axi_cmd_bytes,

    // Config to modeline
    // (will be constant when px_rst_drv deasserts)
    output  reg     [XBITS-1:0]     hdisp,
    output  reg     [XBITS-1:0]     hsyncstart,
    output  reg     [XBITS-1:0]     hsyncend,
    output  reg     [XBITS-1:0]     htotal,
    output  reg     [YBITS-1:0]     vdisp,
    output  reg     [YBITS-1:0]     vsyncstart,
    output  reg     [YBITS-1:0]     vsyncend,
    output  reg     [YBITS-1:0]     vtotal,
    output  reg     [1:0]           pos_r,
    output  reg     [1:0]           pos_g,
    output  reg     [1:0]           pos_b,
    output  reg     [1:0]           pos_a,
    
    // ** Pixel Domain **

    // System
    input   wire                    px_clk,
    input   wire                    px_rst_in,
    output  wire                    px_rst_bus, // just reset bus interface logic
    output  wire                    px_rst_drv, // reset output driver

    // Status
    input   wire                    px_frame_start,
    input   wire                    px_frame_done,
    input   wire                    px_underrun,
    
    // Command to unpacker
    input   wire                    px_cmd_ready,
    output  wire                    px_cmd_valid,
    output  wire    [1:0]           px_cmd_offset,
    output  wire    [1:0]           px_cmd_bpw,
    output  wire    [XBITS-1:0]     px_cmd_words
);

localparam  REG_CONTROL     = 4'h0,
            REG_STATUS      = 4'h1,
            REG_INT_FLAGS   = 4'h2,
            REG_INT_SELECT  = 4'h3,
            REG_BUF_ADDR    = 4'h4,
            REG_BPR         = 4'h5,
            REG_STEP        = 4'h6,
            REG_PXCFG       = 4'h7,
            REG_HDISP       = 4'h8,
            REG_HSYNCSTART  = 4'h9,
            REG_HSYNCEND    = 4'hA,
            REG_HTOTAL      = 4'hB,
            REG_VDISP       = 4'hC,
            REG_VSYNCSTART  = 4'hD,
            REG_VSYNCEND    = 4'hE,
            REG_VTOTAL      = 4'hF;

// 0x0: control (RW)
//  [0]     : enable
// 0x1: status (RO)
//  [15:0]  : minimum buffer level (reset on read)
//  [16]    : px_rst
//  [17]    : axi_busy
// 0x2: int flags (RW; write 1 to clear)
//  [0]     : frame start
//  [1]     : frame done
//  [2]     : buffer underrun
//  [3]     : disabled by px_rst
//  [4]     : axi_error
// 0x3: int select (RW)
// 0x4: buffer address (RW; latched at end of each frame (in preparation for next frame))
//
// these config registers are only writeable when ctrl_enable is cleared:
//
// 0x5: bytes per row (pixels only; excluding padding; must equal hdisp*bytes_per_pixel)
// 0x6: row step (total bytes per row, including padding)
// 0x7: pixel config
//  [ 1: 0] : bytes per pixel (0-3)
//  [ 5: 4] : red pos (0-3)
//  [ 9: 8] : green pos (0-3)
//  [13:12] : blue pos (0-3)
//  [17:16] : alpha pos (0-3)
// 0x8: hdisp
// 0x9: hsyncstart
// 0xA: hsyncend
// 0xB: htotal
// 0xC: vdisp
// 0xD: vsyncstart
// 0xE: vsyncend
// 0xF: vtotal

// synchronize status from pixel domain

wire            rst_from_px;
wire            frame_start;
wire            frame_done;
wire            underrun;

dlsc_syncflop #(
    .DATA           ( 1 ),
    .RESET          ( 1'b1 )
) dlsc_syncflop_rst_from_px (
    .in             ( px_rst_in ),
    .clk            ( clk ),
    .rst            ( rst_in ),
    .out            ( rst_from_px )
);

dlsc_domaincross_pulse dlsc_domaincross_pulse_frame_start (
    .in_clk         ( px_clk ),
    .in_rst         ( px_rst_drv ),
    .in_pulse       ( px_frame_start ),
    .out_clk        ( clk ),
    .out_rst        ( rst_drv ),
    .out_pulse      ( frame_start )
);

dlsc_domaincross_pulse dlsc_domaincross_pulse_frame_done (
    .in_clk         ( px_clk ),
    .in_rst         ( px_rst_drv ),
    .in_pulse       ( px_frame_done ),
    .out_clk        ( clk ),
    .out_rst        ( rst_drv ),
    .out_pulse      ( frame_done )
);

dlsc_domaincross_pulse dlsc_domaincross_pulse_underrun (
    .in_clk         ( px_clk ),
    .in_rst         ( px_rst_drv ),
    .in_pulse       ( px_underrun ),
    .out_clk        ( clk ),
    .out_rst        ( rst_drv ),
    .out_pulse      ( underrun )
);

// register access

wire    [3:0]   csr_addr        = apb_addr[5:2];
wire    [31:0]  csr_wdata       = apb_wdata;
wire    [31:0]  csr_rd          = {32{(apb_sel && !apb_enable && !apb_write)}};
wire    [31:0]  csr_wr          = {32{(apb_sel && !apb_enable &&  apb_write)}} &
                                    { {8{apb_strb[3]}},{8{apb_strb[2]}},{8{apb_strb[1]}},{8{apb_strb[0]}} };

// control register

reg             ctrl_enable;

wire [31:0]     csr_control     = { 31'd0, ctrl_enable };

always @(posedge clk) begin
    if(rst_in) begin
        ctrl_enable     <= 1'b0;
    end else begin
        if(csr_addr == REG_CONTROL && csr_wr[0]) begin
            ctrl_enable     <= csr_wdata[0];
        end
        if(ctrl_enable && rst_from_px) begin
            ctrl_enable     <= 1'b0;
        end
    end
end

// status register

wire [31:0]     csr_status      = { 14'd0, axi_busy, rst_from_px, 16'd0 }; // TODO: implement minimum buffer level

// interrupts

reg  [4:0]      int_flags;
reg  [4:0]      int_select;

wire [31:0]     csr_int_flags   = { 27'd0, int_flags };
wire [31:0]     csr_int_select  = { 27'd0, int_select };

always @(posedge clk) begin
    if(rst_in) begin
        int_flags       <= 0;
        int_select      <= 0;
        int_out         <= 1'b0;
    end else begin

        if(csr_addr == REG_INT_FLAGS) begin
            // clear flags when written with a 1
            int_flags       <= int_flags & ~(csr_wr[4:0] & csr_wdata[4:0]);
        end
        if(csr_addr == REG_INT_SELECT) begin
            int_select      <= (int_select & ~csr_wr[4:0]) | (csr_wdata[4:0] & csr_wr[4:0]);
        end

        if(frame_start) begin
            int_flags[0]    <= 1'b1;
        end
        if(frame_done) begin
            int_flags[1]    <= 1'b1;
        end
        if(underrun) begin
            int_flags[2]    <= 1'b1;
        end
        if(ctrl_enable && rst_from_px) begin
            int_flags[3]    <= 1'b1;
        end
        if(axi_error) begin
            int_flags[4]    <= 1'b1;
        end
        
        int_out         <= |(int_flags & int_select);

    end
end

// buffer address

reg  [AXI_ADDR-1:0] buf_addr;

always @(posedge clk) begin
    if(rst_in) begin
        buf_addr        <= 0;
    end else begin
        if(csr_addr == REG_BUF_ADDR) begin
            buf_addr        <= (buf_addr & ~csr_wr[AXI_ADDR-1:0]) | (csr_wdata[AXI_ADDR-1:0] & csr_wr[AXI_ADDR-1:0]);
        end
    end
end

// other config registers
// (only writeable when !ctrl_enable)

reg  [BLEN-1:0] bytes_per_row;
reg  [AXI_ADDR-1:0] row_step;
reg  [1:0]      bytes_per_pixel;
reg  [1:0]      pos_r;
reg  [1:0]      pos_g;
reg  [1:0]      pos_b;
reg  [1:0]      pos_a;

always @(posedge clk) begin
    if(rst_in) begin
/* verilator lint_off WIDTH */
        bytes_per_row   <= BYTES_PER_ROW;
        row_step        <= ROW_STEP;
        bytes_per_pixel <= BYTES_PER_PIXEL-1;
        pos_r           <= RED_POS;
        pos_g           <= GREEN_POS;
        pos_b           <= BLUE_POS;
        pos_a           <= ALPHA_POS;
        hdisp           <= HDISP-1;
        hsyncstart      <= HSYNCSTART-1;
        hsyncend        <= HSYNCEND-1;
        htotal          <= HTOTAL-1;
        vdisp           <= VDISP-1;
        vsyncstart      <= VSYNCSTART-1;
        vsyncend        <= VSYNCEND-1;
        vtotal          <= VTOTAL-1;
/* verilator lint_on WIDTH */
    end else if(!ctrl_enable) begin
        if(csr_addr == REG_BPR) begin
            bytes_per_row   <= (bytes_per_row   & ~csr_wr[BLEN-1:0])        | (csr_wdata[BLEN-1:0]      & csr_wr[BLEN-1:0]);
        end
        if(csr_addr == REG_STEP) begin
            row_step        <= (row_step        & ~csr_wr[AXI_ADDR-1:0])    | (csr_wdata[AXI_ADDR-1:0]  & csr_wr[AXI_ADDR-1:0]);
        end
        if(!FIXED_PIXEL) begin
            if(csr_addr == REG_PXCFG) begin
                bytes_per_pixel <= (bytes_per_pixel & ~csr_wr[1:0])             | (csr_wdata[1:0]           & csr_wr[1:0]);
                pos_r           <= (pos_r           & ~csr_wr[5:4])             | (csr_wdata[5:4]           & csr_wr[5:4]);
                pos_g           <= (pos_g           & ~csr_wr[9:8])             | (csr_wdata[9:8]           & csr_wr[9:8]);
                pos_b           <= (pos_b           & ~csr_wr[13:12])           | (csr_wdata[13:12]         & csr_wr[13:12]);
                pos_a           <= (pos_a           & ~csr_wr[17:16])           | (csr_wdata[17:16]         & csr_wr[17:16]);
            end
        end
        if(!FIXED_MODELINE) begin
            if(csr_addr == REG_HDISP) begin
                hdisp           <= (hdisp           & ~csr_wr[XBITS-1:0])       | (csr_wdata[XBITS-1:0]     & csr_wr[XBITS-1:0]);
            end
            if(csr_addr == REG_HSYNCSTART) begin
                hsyncstart      <= (hsyncstart      & ~csr_wr[XBITS-1:0])       | (csr_wdata[XBITS-1:0]     & csr_wr[XBITS-1:0]);
            end
            if(csr_addr == REG_HSYNCEND) begin
                hsyncend        <= (hsyncend        & ~csr_wr[XBITS-1:0])       | (csr_wdata[XBITS-1:0]     & csr_wr[XBITS-1:0]);
            end
            if(csr_addr == REG_HTOTAL) begin
                htotal          <= (htotal          & ~csr_wr[XBITS-1:0])       | (csr_wdata[XBITS-1:0]     & csr_wr[XBITS-1:0]);
            end
            if(csr_addr == REG_VDISP) begin
                vdisp           <= (vdisp           & ~csr_wr[YBITS-1:0])       | (csr_wdata[YBITS-1:0]     & csr_wr[YBITS-1:0]);
            end
            if(csr_addr == REG_VSYNCSTART) begin
                vsyncstart      <= (vsyncstart      & ~csr_wr[YBITS-1:0])       | (csr_wdata[YBITS-1:0]     & csr_wr[YBITS-1:0]);
            end
            if(csr_addr == REG_VSYNCEND) begin
                vsyncend        <= (vsyncend        & ~csr_wr[YBITS-1:0])       | (csr_wdata[YBITS-1:0]     & csr_wr[YBITS-1:0]);
            end
            if(csr_addr == REG_VTOTAL) begin
                vtotal          <= (vtotal          & ~csr_wr[YBITS-1:0])       | (csr_wdata[YBITS-1:0]     & csr_wr[YBITS-1:0]);
            end
        end
    end
end

reg  [31:0]     csr_pxcfg;
always @* begin
    csr_pxcfg       = 0;
    csr_pxcfg[1:0]  = bytes_per_pixel;
    csr_pxcfg[5:4]  = pos_r;
    csr_pxcfg[9:8]  = pos_g;
    csr_pxcfg[13:12]= pos_b;
    csr_pxcfg[17:16]= pos_a;
end

// register read

always @(posedge clk) begin
    apb_ready       <= (apb_sel && !apb_enable);
    apb_rdata       <= 32'd0;
    if(apb_sel && !apb_enable && !apb_write) begin
        case(csr_addr)
            REG_CONTROL:    apb_rdata               <= csr_control;
            REG_STATUS:     apb_rdata               <= csr_status;
            REG_INT_FLAGS:  apb_rdata               <= csr_int_flags;
            REG_INT_SELECT: apb_rdata               <= csr_int_select;
            REG_BUF_ADDR:   apb_rdata[AXI_ADDR-1:0] <= buf_addr;
            REG_BPR:        apb_rdata[BLEN-1:0]     <= bytes_per_row;
            REG_STEP:       apb_rdata[AXI_ADDR-1:0] <= row_step;
            REG_PXCFG:      apb_rdata               <= csr_pxcfg;
            REG_HDISP:      apb_rdata[XBITS-1:0]    <= hdisp;
            REG_HSYNCSTART: apb_rdata[XBITS-1:0]    <= hsyncstart;
            REG_HSYNCEND:   apb_rdata[XBITS-1:0]    <= hsyncend;
            REG_HTOTAL:     apb_rdata[XBITS-1:0]    <= htotal;
            REG_VDISP:      apb_rdata[YBITS-1:0]    <= vdisp;
            REG_VSYNCSTART: apb_rdata[YBITS-1:0]    <= vsyncstart;
            REG_VSYNCEND:   apb_rdata[YBITS-1:0]    <= vsyncend;
            REG_VTOTAL:     apb_rdata[YBITS-1:0]    <= vtotal;
            default:        apb_rdata               <= 0;
        endcase
    end
end

// resets

reg             st_rst_bus;     // st == ST_RST || st == ST_UR_RST
reg             st_rst_drv;     // st == ST_RST || st == ST_HALT

assign          rst_bus         = rst_in || st_rst_bus;
assign          rst_drv         = rst_in || st_rst_drv;

wire            px_st_rst_bus;
wire            px_st_rst_drv;

dlsc_syncflop #(
    .DATA           ( 2 ),
    .RESET          ( 2'b11 )
) dlsc_syncflop_px_st_rst (
    .in             ( { st_rst_drv, st_rst_bus } ),
    .clk            ( px_clk ),
    .rst            ( px_rst_in ),
    .out            ( { px_st_rst_drv, px_st_rst_bus } )
);

assign          px_rst_bus      = px_rst_in || px_st_rst_bus;
assign          px_rst_drv      = px_rst_in || px_st_rst_drv;

// synchronize unpacker command

wire            up_cmd_ready;
wire            up_cmd_valid;
wire [1:0]      up_cmd_offset;
wire [1:0]      up_cmd_bpw;
wire [XBITS-1:0] up_cmd_words;

assign          px_cmd_bpw      = up_cmd_bpw;   // should be constant when px_rst_bus deasserts
assign          px_cmd_words    = hdisp;        // ""

dlsc_domaincross_rvh #(
    .DATA           ( 2 )
) dlsc_domaincross_rvh_px_cmd (
    .in_clk         ( clk ),
    .in_rst         ( rst_bus ),
    .in_ready       ( up_cmd_ready ),
    .in_valid       ( up_cmd_valid ),
    .in_data        ( up_cmd_offset ),
    .out_clk        ( px_clk ),
    .out_rst        ( px_rst_bus ),
    .out_ready      ( px_cmd_ready ),
    .out_valid      ( px_cmd_valid ),
    .out_data       ( px_cmd_offset )
);

// control states

localparam  ST_HALT     = 1,    // disabling; wait for AXI to halt
            ST_RST      = 0,    // disabled; most logic placed in reset (AXI halted)
            ST_INIT     = 2,    // wait for reset to be removed
            ST_START    = 3,    // fetching a new frame
            ST_WAIT     = 4,    // waiting for frame to complete
            ST_UR_HALT  = 5,    // underrun; wait for AXI to halt
            ST_UR_RST   = 6,    // underrun; AXI halted; reset AXI
            ST_UR_INIT  = 7;    // underrun; wait for reset removal

reg  [2:0]      st;
reg  [2:0]      next_st;

reg  [3:0]      rst_cnt;
reg             rst_cnt_clr;
wire            rst_cnt_max     = &rst_cnt;

always @* begin

    next_st     = st;

    rst_cnt_clr = 1'b1;

    // ** reset handling **

    if(st == ST_HALT) begin
        rst_cnt_clr = 1'b0;
        if(rst_cnt_max && !axi_busy) begin
            next_st     = ST_RST;
            rst_cnt_clr = 1'b1;
        end
    end
    if(st == ST_RST && ctrl_enable) begin
        rst_cnt_clr = 1'b0;
        if(rst_cnt_max) begin
            next_st     = ST_INIT;
            rst_cnt_clr = 1'b1;
        end
    end
    if(st == ST_INIT) begin
        rst_cnt_clr = 1'b0;
        if(rst_cnt_max) begin
            next_st     = ST_START;
            rst_cnt_clr = 1'b1;
        end
    end

    // ** normal operation **

    if(st == ST_START) begin
        // command driven; wait for frame completion
        next_st     = ST_WAIT;
    end
    if(st == ST_WAIT) begin
        if(frame_done) begin
            // frame completed; start fetching next frame
            next_st     = ST_START;
        end
    end

    // ** underrun/error handling **

    if(st == ST_UR_HALT) begin
        rst_cnt_clr = 1'b0;
        if(rst_cnt_max && !axi_busy) begin
            next_st     = ST_UR_RST;
            rst_cnt_clr = 1'b1;
        end
    end
    if(st == ST_UR_RST) begin
        rst_cnt_clr = 1'b0;
        if(rst_cnt_max) begin
            // reset applied for a bit; now remove it
            next_st     = ST_UR_INIT;
            rst_cnt_clr = 1'b1;
        end
    end
    if(st == ST_UR_INIT) begin
        rst_cnt_clr = 1'b0;
        if(rst_cnt_max) begin
            // finished reset; wait for frame completion to start fetching again
            next_st     = ST_WAIT;
            rst_cnt_clr = 1'b1;
        end
    end

    if( ctrl_enable && (underrun || axi_error) && !(st == ST_UR_HALT || st == ST_UR_RST) ) begin
        // halt on error, in prep for reset
        next_st     = ST_UR_HALT;
        rst_cnt_clr = 1'b1;
    end

    if( !ctrl_enable && !(st == ST_HALT || st == ST_RST) ) begin
        // halt when disabled, in prep for reset
        next_st     = ST_HALT;
        rst_cnt_clr = 1'b1;
    end

end

always @(posedge clk) begin
    if(rst_cnt_clr) begin
        rst_cnt     <= 0;
    end else begin
        rst_cnt     <= rst_cnt + 1;
    end
end

always @(posedge clk) begin
    if(rst_in) begin
        st          <= ST_RST;
        st_rst_drv  <= 1'b1;
        st_rst_bus  <= 1'b1;
        axi_halt    <= 1'b1;
    end else begin
        st          <= next_st;
        
        // output driver should be immediately reset upon disable
        st_rst_drv  <= next_st == ST_RST    || next_st == ST_HALT;
        
        // bus interface can only be reset once the bus is idle
        st_rst_bus  <= next_st == ST_RST    || next_st == ST_UR_RST;

        // halt bus in prep for reset
        axi_halt    <= next_st == ST_RST    || next_st == ST_HALT ||
                       next_st == ST_UR_RST || next_st == ST_UR_HALT;
    end
end

// generate commands

wire            cmd_ready       = (axi_cmd_ready && up_cmd_ready);
reg             cmd_valid;

reg [AXI_ADDR-1:0] cmd_addr;

assign          axi_cmd_valid   = cmd_valid && up_cmd_ready;
assign          axi_cmd_addr    = cmd_addr;
assign          axi_cmd_bytes   = bytes_per_row;

assign          up_cmd_valid    = cmd_valid && axi_cmd_ready;
assign          up_cmd_offset   = cmd_addr[1:0];
assign          up_cmd_bpw      = bytes_per_pixel;
assign          up_cmd_words    = hdisp;

reg [YBITS-1:0] row;
wire            row_last    = (row == 0);

always @(posedge clk) begin
    if(rst_bus) begin
        cmd_valid   <= 1'b0;
        row         <= 0;
    end else begin

        if(cmd_ready) begin
            cmd_valid   <= 1'b0;
        end

        if(!cmd_valid && !row_last) begin
            cmd_valid   <= 1'b1;
            row         <= row - 1;
        end

        if(st == ST_START) begin
            cmd_valid   <= 1'b1;
            row         <= vdisp;
        end

    end
end

always @(posedge clk) begin
    if(!cmd_valid && !row_last) begin
        // advance to next row
        cmd_addr    <= cmd_addr + row_step;
    end
    if(st == ST_START) begin
        // start from beginning of buffer
        cmd_addr    <= buf_addr;
    end
end


// simulation checks

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

reg ctrl_enable_prev;

integer i;
integer j;

always @(posedge clk) if(!rst_in) begin
    if(!ctrl_enable_prev && ctrl_enable) begin
        i = bytes_per_row;
        j = (hdisp+1) * (bytes_per_pixel+1);
        if(i != j) begin
            `dlsc_error("bytes_per_row (%d) != hdisp*bytes_per_pixel (%d)",i,j);
        end
        if(row_step < bytes_per_row) begin
            `dlsc_warn("row_step should be >= bytes_per_row");
        end
        if(htotal < hdisp || htotal < hsyncstart || htotal < hsyncend) begin
            `dlsc_error("htotal must be larger than other parameters");
        end
        if(vtotal < vdisp || vtotal < vsyncstart || vtotal < vsyncend) begin
            `dlsc_error("vtotal must be larger than other parameters");
        end
        if(hsyncstart >= hsyncend) begin
            `dlsc_error("hsyncstart must be < hsyncend");
        end
        if(vsyncstart >= vsyncend) begin
            `dlsc_error("vsyncstart must be < vsyncend");
        end
    end
    ctrl_enable_prev = ctrl_enable;
end

always @(posedge clk) if(!rst_bus) begin
    if(st == ST_START && (cmd_valid || !row_last)) begin
        `dlsc_error("ST_START entered before command generator was done");
    end
end

always @(posedge clk) if(!rst_in) begin
    if(apb_sel && apb_write && !apb_enable && ctrl_enable && apb_addr[5:2] >= 4'h5) begin
        `dlsc_info("ignored write to register 0x%0x when ctrl_enable asserted", apb_addr[5:2]);
    end
    if(underrun) begin
        `dlsc_info("got underrun");
    end
end


`include "dlsc_sim_bot.vh"
`endif


endmodule

