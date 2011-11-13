
module dlsc_pxdma_control #(
    parameter APB_ADDR          = 32,
    parameter AXI_ADDR          = 32,
    parameter BYTES_PER_PIXEL   = 3,
    parameter BLEN              = 12,
    parameter XBITS             = 12,
    parameter YBITS             = 12,
    parameter ACKS              = 1,
    parameter WRITER            = 0,    // set for pxdma_writer
    parameter PX_ASYNC          = 0
) (
    // System
    input   wire                    clk,
    input   wire                    rst_in,
    output  wire                    rst_bus,
    input   wire                    px_clk,
    input   wire                    px_rst_in,
    output  wire                    px_rst_bus,

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

    // Status
    output  reg                     enabled,

    // Handshake
    input   wire    [ACKS-1:0]      row_ack,
    output  reg     [ACKS-1:0]      row_done,

    // AXI reader/writer
    output  reg                     axi_halt,
    input   wire                    axi_busy,
    input   wire                    axi_error,
    input   wire                    axi_cmd_done,
    input   wire                    axi_cmd_ready,
    output  reg                     axi_cmd_valid,
    output  reg     [AXI_ADDR-1:0]  axi_cmd_addr,
    output  reg     [BLEN-1:0]      axi_cmd_bytes,

    // Data unpacker/packer
    input   wire                    pack_cmd_ready,
    output  reg                     pack_cmd_valid,
    output  wire    [1:0]           pack_cmd_offset,
    output  wire    [1:0]           pack_cmd_bpw,
    output  wire    [XBITS-1:0]     pack_cmd_words
);

localparam  REG_CONTROL     = 4'h0,
            REG_STATUS      = 4'h1,
            REG_INT_FLAGS   = 4'h2,
            REG_INT_SELECT  = 4'h3,
            REG_BUF0_ADDR   = 4'h4,
            REG_BUF1_ADDR   = 4'h5,
            REG_BPR         = 4'h6,
            REG_STEP        = 4'h7,
            REG_HDISP       = 4'h8,
            REG_VDISP       = 4'h9;

// 0x0: control (RW)
//  [0]     : enable (cleared on error)
//  [1]     : double buffer (only writeable when ctrl_enable is cleared)
// 0x1: status (RO)
//  [0]     : enabled
//  [1]     : next buffer
//  [2]     : axi_busy
//  [3]     : axi_error
//  [4]     : px_rst
// 0x2: int flags (RW; write 1 to clear)
//  [0]     : row start
//  [1]     : row done
//  [2]     : frame start
//  [3]     : frame done
//  [4]     : disabled by px_rst
//  [5]     : axi_error
// 0x3: int select (RW)
// 0x4: buffer 0 address
// 0x5: buffer 1 address
//
// these config registers are only writeable when ctrl_enable is cleared:
//
// 0x6: bytes per row (pixels only; excluding padding; must equal hdisp*bytes_per_pixel)
// 0x7: row step (total bytes per row, including padding)
// 0x8: horizontal resolution
// 0x9: vertical resolution


// ** registers **

wire    [3:0]   csr_addr        = apb_addr[5:2];
wire    [31:0]  csr_wdata       = apb_wdata;
wire    [31:0]  csr_rd          = {32{(apb_sel && !apb_enable && !apb_write)}};
wire    [31:0]  csr_wr          = {32{(apb_sel && !apb_enable &&  apb_write)}} &
                                    { {8{apb_strb[3]}},{8{apb_strb[2]}},{8{apb_strb[1]}},{8{apb_strb[0]}} };

// control

reg             ctrl_enable;
reg             double_buffer;

wire [31:0]     csr_control     = { 30'd0, double_buffer, ctrl_enable };

wire            next_ctrl_enable = (csr_addr == REG_CONTROL && csr_wr[0]) ? csr_wdata[0] : ctrl_enable;

always @(posedge clk) begin
    if(rst_in) begin
        ctrl_enable     <= 1'b0;
        double_buffer   <= 1'b0;
    end else begin

        ctrl_enable     <= next_ctrl_enable;
        
        if(csr_addr == REG_CONTROL && (!ctrl_enable || !next_ctrl_enable)) begin
            // other control bits can only be changed when ctrl_enable isn't set
            if(csr_wr[1]) double_buffer <= csr_wdata[1];
        end

        if( (axi_error && !axi_halt) || obs_px_rst ) begin
            // clear enable on error
            ctrl_enable     <= 1'b0;
        end

    end
end

// status

reg             next_buffer;
wire            obs_px_rst;

wire [31:0]     csr_status      = { 27'd0, obs_px_rst, axi_error, axi_busy, next_buffer, enabled };

// interrupts

reg  [5:0]      int_flags;
reg  [5:0]      int_select;

wire [31:0]     csr_int_flags   = { 26'd0, int_flags };
wire [31:0]     csr_int_select  = { 26'd0, int_select };

wire            set_row_start;
wire            set_row_done;
wire            set_frame_start;
wire            set_frame_done;
wire            set_disabled    = next_ctrl_enable && obs_px_rst;
wire            set_axi_error   = axi_error && !axi_halt;

always @(posedge clk) begin
    if(rst_in) begin
        int_flags       <= 0;
        int_select      <= 0;
        int_out         <= 1'b0;
    end else begin

        if(csr_addr == REG_INT_FLAGS) begin
            // clear flags when written with a 1
            int_flags       <= int_flags & ~(csr_wr[5:0] & csr_wdata[5:0]);
        end
        if(csr_addr == REG_INT_SELECT) begin
            int_select      <= (int_select & ~csr_wr[5:0]) | (csr_wdata[5:0] & csr_wr[5:0]);
        end

        if(set_row_start)   int_flags[0] <= 1'b1;
        if(set_row_done)    int_flags[1] <= 1'b1;
        if(set_frame_start) int_flags[2] <= 1'b1;
        if(set_frame_done)  int_flags[3] <= 1'b1;
        if(set_disabled)    int_flags[4] <= 1'b1;
        if(set_axi_error)   int_flags[5] <= 1'b1;
        
        int_out         <= |(int_flags & int_select);

    end
end

// buffer addresses

reg  [AXI_ADDR-1:0] buf0_addr;
reg  [AXI_ADDR-1:0] buf1_addr;

always @(posedge clk) begin
    if(csr_addr == REG_BUF0_ADDR) begin
        buf0_addr       <= (buf0_addr & ~csr_wr[AXI_ADDR-1:0]) | (csr_wdata[AXI_ADDR-1:0] & csr_wr[AXI_ADDR-1:0]);
    end
    if(csr_addr == REG_BUF1_ADDR) begin
        buf1_addr       <= (buf1_addr & ~csr_wr[AXI_ADDR-1:0]) | (csr_wdata[AXI_ADDR-1:0] & csr_wr[AXI_ADDR-1:0]);
    end
end

// other config registers
// (only writeable when !ctrl_enable)

reg  [BLEN-1:0] bytes_per_row;
reg  [AXI_ADDR-1:0] row_step;
reg  [XBITS-1:0] hdisp;
reg  [YBITS-1:0] vdisp;

always @(posedge clk) begin
    if(!ctrl_enable) begin
        if(csr_addr == REG_BPR) begin
            bytes_per_row   <= (bytes_per_row   & ~csr_wr[BLEN-1:0])        | (csr_wdata[BLEN-1:0]      & csr_wr[BLEN-1:0]);
        end
        if(csr_addr == REG_STEP) begin
            row_step        <= (row_step        & ~csr_wr[AXI_ADDR-1:0])    | (csr_wdata[AXI_ADDR-1:0]  & csr_wr[AXI_ADDR-1:0]);
        end
        if(csr_addr == REG_HDISP) begin
            hdisp           <= (hdisp           & ~csr_wr[XBITS-1:0])       | (csr_wdata[XBITS-1:0]     & csr_wr[XBITS-1:0]);
        end
        if(csr_addr == REG_VDISP) begin
            vdisp           <= (vdisp           & ~csr_wr[YBITS-1:0])       | (csr_wdata[YBITS-1:0]     & csr_wr[YBITS-1:0]);
        end
    end
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
            REG_BUF0_ADDR:  apb_rdata[AXI_ADDR-1:0] <= buf0_addr;
            REG_BUF1_ADDR:  apb_rdata[AXI_ADDR-1:0] <= buf1_addr;
            REG_BPR:        apb_rdata[BLEN-1:0]     <= bytes_per_row;
            REG_STEP:       apb_rdata[AXI_ADDR-1:0] <= row_step;
            REG_HDISP:      apb_rdata[XBITS-1:0]    <= hdisp;
            REG_VDISP:      apb_rdata[YBITS-1:0]    <= vdisp;
            default:        apb_rdata               <= 0;
        endcase
    end
end


// create enabled

always @(posedge clk) begin
    if(rst_in) begin
        axi_halt    <= 1'b1;
        enabled     <= 1'b0;
    end else begin
        if(ctrl_enable && !enabled) begin
            // only enable once completely disabled
            // (in case ctrl_enable deasserts and reasserts before bus becomes idle)
            axi_halt    <= 1'b0;
            enabled     <= 1'b1;
        end
        if(!ctrl_enable) begin
            // halt before disabling
            axi_halt    <= 1'b1;
        end
        if(axi_halt && !axi_busy) begin
            // only disable once AXI bus is idle
            enabled     <= 1'b0;
        end
    end
end


// ** resets **

assign          rst_bus         = rst_in || !enabled;

wire            px_enabled;
assign          px_rst_bus      = px_rst_in || !px_enabled;

generate
if(PX_ASYNC) begin:GEN_ASYNC

    dlsc_syncflop #(
        .DATA       ( 1 ),
        .RESET      ( 1'b1 )
    ) dlsc_syncflop_obs_px_rst (
        .in         ( px_rst_in ),
        .clk        ( clk ),
        .rst        ( rst_in ),
        .out        ( obs_px_rst )
    );

    dlsc_syncflop #(
        .DATA       ( 1 ),
        .RESET      ( 1'b0 )
    ) dlsc_syncflop_px_enabled (
        .in         ( enabled ),
        .clk        ( px_clk ),
        .rst        ( px_rst_in ),
        .out        ( px_enabled )
    );

end else begin:GEN_SYNC

    assign obs_px_rst   = px_rst_in;

    assign px_enabled   = enabled;

end
endgenerate


// ** commands **

assign          axi_cmd_bytes   = bytes_per_row;

assign          pack_cmd_offset = axi_cmd_addr[1:0];
assign          pack_cmd_words  = hdisp;
/* verilator lint_off WIDTH */
assign          pack_cmd_bpw    = BYTES_PER_PIXEL-1;
/* verilator lint_on WIDTH */

wire            ack_okay;

reg [YBITS-1:0] cmd_row;
reg             cmd_row_first;
reg             cmd_row_last;

wire            cmd_update      = ack_okay && !axi_cmd_valid && !pack_cmd_valid && enabled;

assign          set_row_start   = cmd_update;
assign          set_row_done    = axi_cmd_done;
assign          set_frame_start = cmd_update && cmd_row_first;
assign          set_frame_done  = axi_cmd_done && 1'b0; // TODO

always @(posedge clk) begin
    if(!enabled) begin
        axi_cmd_valid   <= 1'b0;
        pack_cmd_valid  <= 1'b0;
        row_done        <= 0;
    end else begin
        axi_cmd_valid   <= (axi_cmd_valid  && !axi_cmd_ready ) || cmd_update;
        pack_cmd_valid  <= (pack_cmd_valid && !pack_cmd_ready) || cmd_update;
        row_done        <= {ACKS{axi_cmd_done}};
    end
end

always @(posedge clk) begin
    if(cmd_update) begin
        if(cmd_row_first) begin
            // grab new buffer address for first row
            axi_cmd_addr    <= next_buffer ? buf1_addr : buf0_addr;
        end else begin
            // advance to next row
            axi_cmd_addr    <= axi_cmd_addr + row_step;
        end
    end
end

always @(posedge clk) begin
    if(!enabled) begin
        next_buffer     <= 1'b0;
        cmd_row         <= 1;
        cmd_row_first   <= 1'b1;
        cmd_row_last    <= 1'b0;
    end else if(cmd_update) begin

        if(cmd_row_first && double_buffer) begin
            // change buffers after we grab the address
            next_buffer     <= !next_buffer;
        end

        if(cmd_row_last) begin
            cmd_row         <= 1;
            cmd_row_first   <= 1'b1;
            cmd_row_last    <= 1'b0;
        end else begin
            cmd_row         <= cmd_row + 1;
            cmd_row_first   <= 1'b0;
            cmd_row_last    <= ( (cmd_row+1) == vdisp );
        end
            
    end
end


// ** ack counter(s) **

wire [ACKS-1:0] ack_valids;
assign          ack_okay        = &ack_valids;

genvar j;
generate
for(j=0;j<ACKS;j=j+1) begin:GEN_ACKS

    // YBITS+1, to handle 2 buffers worth of rows
    reg [YBITS:0]   ack_cnt;
    reg [YBITS:0]   next_ack_cnt;
    
    reg             ack_valid_r;
    assign          ack_valids[j]   = ack_valid_r;

    always @* begin
        next_ack_cnt = ack_cnt;
        if(row_ack[j]) begin
            next_ack_cnt = next_ack_cnt + 1;
        end
        if(cmd_update) begin
            next_ack_cnt = next_ack_cnt - 1;
        end
    end

    always @(posedge clk) begin
        if(!enabled) begin
            ack_valid_r <= 1'b0;
            if(WRITER) begin
                // writer begins full
                if(double_buffer) begin
                    // two buffers worth of space
                    ack_cnt     <= {vdisp,1'b0}; // vdisp*2
                end else begin
                    // one buffer
                    ack_cnt     <= {1'b0,vdisp}; // vdisp*1
                end
            end else begin
                // reader begins empty
                ack_cnt     <= 0;
            end
        end else begin
            ack_valid_r <= (next_ack_cnt != 0);
            ack_cnt     <= next_ack_cnt;
        end
    end
    
    // simulation checks
    `ifdef DLSC_SIMULATION
    `include "dlsc_sim_top.vh"

    always @(posedge clk) begin
        if(row_ack[j] && ((!double_buffer && ack_cnt >= {1'b0,vdisp}) ||
                          ( double_buffer && ack_cnt >= {vdisp,1'b0})) )
        begin
            `dlsc_error("ack_cnt overflow");
        end
    end

    `include "dlsc_sim_bot.vh"
    `endif

end
endgenerate


// simulation checks

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

reg ctrl_enable_prev;

always @(posedge clk) if(!rst_in) begin
    if(!ctrl_enable_prev && ctrl_enable) begin
        if( bytes_per_row != (BYTES_PER_PIXEL * {2'b00,hdisp}) ) begin
            `dlsc_error("bytes_per_row (%d) != hdisp*bytes_per_pixel (%d)",bytes_per_row,(BYTES_PER_PIXEL * {2'b00,hdisp}));
        end
        if(row_step < bytes_per_row) begin
            `dlsc_warn("row_step should be >= bytes_per_row");
        end
    end
    ctrl_enable_prev = ctrl_enable;
end

always @(posedge clk) if(!rst_in) begin
    if(apb_sel && apb_write && !apb_enable && ctrl_enable && apb_addr[5:2] >= 4'h6) begin
        `dlsc_info("ignored write to register 0x%0x when ctrl_enable asserted", apb_addr[5:2]);
    end
end


`include "dlsc_sim_bot.vh"
`endif


endmodule

