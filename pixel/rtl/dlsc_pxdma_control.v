// 
// Copyright (c) 2012, Daniel Strother < http://danstrother.com/ >
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//   - Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//   - Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in the
//     documentation and/or other materials provided with the distribution.
//   - The name of the author may not be used to endorse or promote products
//     derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
// WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
// EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
// TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

// Module Description:
// Common control logic for pxdma_reader and pxdma_writer.
//
// ** Buffers **
//
// A FIFO is provided to store addresses for multiple buffers. Each buffer can
// contain an integer number of rows. Buffers may be smaller than a frame, but
// should never be larger (ROWS_PER_BUFFER must be <= ROWS_PER_FRAME). A single
// buffer may contain rows from multiple frames (if ROWS_PER_FRAME is not an
// integer multiple of ROWS_PER_BUFFER), though this is not recommended.
//
// To insert padding between rows, use ROW_STEP to set the spacing between the
// beginnings of each row. The effective padding between rows is then:
//  ROW_STEP - BYTES_PER_ROW
// This padding is only inserted between rows within a single buffer. If each
// buffer contains only 1 row, then ROW_STEP is not used. Padding bytes are
// not modified by the DMA engine (they are merely skipped).
//
// All buffers must be the same size: ROW_STEP * ROWS_PER_BUFFER
//
// There is no alignment requirement for buffer addresses. The DMA engine can
// handle arbitrary byte alignments and sizes. Write strobes will be used when
// words are only partially filled with bytes.
//
// ** Modes **
//
// Normal mode:
//  Buffer addresses are only used once. The address FIFO may have new addresses
//  written to it at any time.
//
// Auto mode:
//  Buffer addresses are automatically re-used. The address FIFO must be filled
//  while the engine is disabled. Once enabled, addresses that the engine pops
//  from the FIFO are automatically pushed to the back of the FIFO. Once each
//  address has been used once, the writer will wait for ACKs from readers before
//  over-writing any buffers.
//
// ** Handshaking **
//
// A handshake mechanism is provided to allow DMA readers to automatically start
// reading data as the DMA writer finishes writing. Each time the writer
// completes a row, it asserts csr_row_done to signal the reader(s) that another
// row is available. Readers are only permitted to read as many rows as have
// already been ACKed.
//
// In auto mode, this handshake mechanism is also used to prevent DMA writers
// from overwriting buffers that have not yet been read. Each time a reader
// finishes reading a row, it asserts csr_row_done to signal the writer(s) that
// another row has been freed. After exhausting the initial complement of
// buffers, writers are only permitted to write as many rows as have already
// been ACKed.
//
// A CPU may also handshake with the DMA engine by means of the internal
// ACK_ROWS register. When the CPU has finished with some number of buffer rows,
// it can write this number to the ACK_ROWS register to inform the DMA engine
// that the engine can proceed.
//
// ** Enable **
//
// Once completely configured, the DMA engine is started by setting the Enable
// flag in the CONTROL register. When enabled, critical configuration registers
// become read-only. In the event of a fault, the engine is automatically
// disabled. Interrupt flag(s) are set to indicate this.
//
// On disable (either from a fault or by manually clearing the Enable flag), the
// AXI DMA engine is allowed to complete any outstanding transactions before
// being disabled. This prevents deadlocking the bus. The Enabled flag in the
// STATUS register will be cleared once the DMA engine has become idle and been
// disabled. The Disabled interrupt flag will also be set when this occurs.
//
// If the Enable flag in the CONTROL register is set before the engine has
// finished disabling, the engine will wait until it has become disabled and
// then automatically re-enable.

module dlsc_pxdma_control #(
    // ** Clock Domains **
    parameter CSR_DOMAIN        = 0,
    parameter AXI_DOMAIN        = 1,
    parameter PX_DOMAIN         = 2,
    // ** Config **
    parameter WRITER            = 0,        // set for pxdma_writer
    parameter ACKS              = 1,        // number of external ACK clients
    parameter AF_ADDR           = 4,        // address bits for Buffer Address FIFO
    parameter BYTES_PER_PIXEL   = 3,
    parameter XBITS             = 12,       // bits for X resolution
    parameter YBITS             = 12,       // bits for Y resolution
    parameter BLEN              = 14,       // bits for bytes in a row (= XBITS + clog2(BYTES_PER_PIXEL))
    // ** AXI **
    parameter AXI_ADDR          = 32,       // size of AXI address field
    parameter AXI_MOT           = 16,       // maximum outstanding transactions
    // ** CSR **
    parameter CSR_ADDR          = 32,
    parameter CORE_MAGIC        = 32'h0bc7f29c,         // 32-bit identifier to place in REG_CORE_MAGIC field
    parameter CORE_INSTANCE     = 32'h00000000          // 32-bit identifier to place in REG_CORE_INSTANCE field
) (

    // ** CSR Domain **

    // System
    input   wire                    csr_clk,
    input   wire                    csr_rst,
    output  wire                    csr_rst_out,

    // Status
    output  wire                    csr_enabled,

    // Handshake
    input   wire    [ACKS-1:0]      csr_row_ack,
    output  reg     [ACKS-1:0]      csr_row_done,
    
    // CSR command
    input   wire                    csr_cmd_valid,
    input   wire                    csr_cmd_write,
    input   wire    [CSR_ADDR-1:0]  csr_cmd_addr,
    input   wire    [31:0]          csr_cmd_data,

    // CSR response
    output  reg                     csr_rsp_valid,
    output  reg                     csr_rsp_error,
    output  reg     [31:0]          csr_rsp_data,

    // Interrupt
    output  reg                     csr_int,


    // ** AXI Doamin **

    // System
    input   wire                    axi_clk,
    input   wire                    axi_rst,
    output  wire                    axi_rst_out,

    // AXI reader/writer
    output  reg                     axi_halt,
    input   wire                    axi_busy,
    input   wire                    axi_error,
    input   wire                    axi_cmd_done,
    input   wire                    axi_cmd_ready,
    output  wire                    axi_cmd_valid,
    output  wire    [AXI_ADDR-1:0]  axi_cmd_addr,
    output  wire    [BLEN-1:0]      axi_cmd_bytes,


    // ** Pixel Domain **
    
    // System
    input   wire                    px_clk,
    input   wire                    px_rst,
    output  wire                    px_rst_out,

    // Data unpacker/packer
    input   wire                    px_cmd_ready,
    output  reg                     px_cmd_valid,
    output  wire    [1:0]           px_cmd_offset,
    output  wire    [1:0]           px_cmd_bpw,
    output  wire    [XBITS-1:0]     px_cmd_words
);

localparam  CORE_VERSION        = 32'h20120707;
localparam  CORE_INTERFACE      = 32'h20120707;

// bits for ack counters.. enough for a full complement of frame-sized buffers
localparam  ABITS   = YBITS + AF_ADDR;


// ** registers **

// 0x04: control
//  [0]     : enable (cleared on error)
//
// 0x05: status
//  [0]     : enabled
//  [1]     : axi_busy
//  [2]     : axi_error
//  [3]     : axi_rst
//  [4]     : px_rst
//
// 0x06: FIFO free count
// 0x07: FIFO: buffer address (WO; push on write)
//
// 0x08: rows completed threshold (RW)
// 0x09: rows completed (RO; clear on read)
//
// 0x0A: buffers completed threshold (RW)
// 0x0B: buffers completed (RO; clear on read)
//
// 0x0C: ack rows
//
// 0x0D: interrupt flags
//  [0]     : disabled
//  [1]     : axi error
//  [2]     : ack counter overflow
//  [3]     : FIFO overflow
//  [4]     : address FIFO empty
//  [5]     : address FIFO half empty
//  [6]     : rows completed hit threshold
//  [7]     : buffers completed hit threshold
//  [8]     : row start
//  [9]     : row done
//  [10]    : frame start
//  [11]    : frame done
//  [12]    : buffer done
// 0x0E: interrupt select
//
// ** only writeable when disabled: **
// 0x10: config
//  [0]     : auto mode
//  [1]     : clear FIFO
// 0x11: ack select
//  [30:0]  : external acks
//  [31]    : internal ack
// 0x12: ack status
//
// 0x13: pixels per row (horizontal resolution)
// 0x14: rows per frame (vertical resolution)
// 0x15: bytes per pixel (RO)
// 0x16: bytes per row (pixels only; excluding padding; must equal bytes_per_pixel * pixels_per_row)
// 0x17: row step (bytes per row including padding between rows; should generally be >= bytes_per_row_raw)
// 0x18: rows per buffer (must be <= rows_per_frame)

localparam  REG_CORE_MAGIC          = 5'h00,
            REG_CORE_VERSION        = 5'h01,
            REG_CORE_INTERFACE      = 5'h02,
            REG_CORE_INSTANCE       = 5'h03;

localparam  REG_CONTROL             = 5'h04,
            REG_STATUS              = 5'h05,
            REG_FIFO_FREE           = 5'h06,
            REG_FIFO                = 5'h07,
            REG_ROWS_COMPLETED      = 5'h08,
            REG_ROWS_THRESH         = 5'h09,
            REG_BUFFERS_COMPLETED   = 5'h0A,
            REG_BUFFERS_THRESH      = 5'h0B,
            REG_ACK_ROWS            = 5'h0C,
            REG_INT_FLAGS           = 5'h0D,
            REG_INT_SELECT          = 5'h0E,
            REG_CONFIG              = 5'h10,
            REG_ACK_SELECT          = 5'h11,
            REG_ACK_STATUS          = 5'h12,
            REG_PIXELS_PER_ROW      = 5'h13,
            REG_ROWS_PER_FRAME      = 5'h14,
            REG_BYTES_PER_PIXEL     = 5'h15,
            REG_BYTES_PER_ROW       = 5'h16,
            REG_ROW_STEP            = 5'h17,
            REG_ROWS_PER_BUFFER     = 5'h18;

wire  [4:0]         csr_addr        = csr_cmd_addr[6:2];

// enable flags

reg                 ctrl_enable;
reg                 next_ctrl_enable;

reg                 disabled;       // engine is completely disabled
reg                 enabled_pre;    // engine is enabled or in the process of enabling
reg                 enabled;        // engine is completely enabled

// observed flags (from other domains)

wire                obs_axi_busy;
wire                obs_axi_error;
wire                obs_axi_rst;
wire                obs_px_rst;

// interrupt set flags

reg                 set_disabled;
wire                set_axi_error       = enabled && obs_axi_error;
wire                set_ack_overflow;
wire                set_fifo_overflow;
wire                set_fifo_empty;
wire                set_fifo_half_empty;
wire                set_rows_completed;
wire                set_bufs_completed;
reg                 set_row_start;
reg                 set_row_done;
reg                 set_frame_start;
reg                 set_frame_done;
reg                 set_buffer_done;

// ** control **

wire [31:0]         csr_control         = {31'd0,ctrl_enable};

always @* begin
    next_ctrl_enable    = ctrl_enable;

    if(csr_cmd_valid && csr_cmd_write && csr_addr == REG_CONTROL) begin
        next_ctrl_enable    = csr_cmd_data[0];
    end

    if(obs_axi_error || obs_axi_rst || obs_px_rst ||
       set_ack_overflow || set_fifo_overflow)
    begin
        next_ctrl_enable    = 1'b0;
    end
end

always @(posedge csr_clk) begin
    if(csr_rst) begin
        ctrl_enable <= 1'b0;
    end else begin
        ctrl_enable <= next_ctrl_enable;
    end
end

// ** status **

reg  [31:0]         csr_status;

always @* begin
    csr_status      = 0;
    
    // want enabled flag to deassert only when engine is truly disabled
    csr_status[0]   = !disabled;

    csr_status[1]   = obs_axi_busy;
    csr_status[2]   = obs_axi_error;
    csr_status[3]   = obs_axi_rst;
    csr_status[4]   = obs_px_rst;
end

// ** interrupts **

localparam INTB = 13;
reg  [INTB-1:0]     int_select;
reg  [INTB-1:0]     int_flags;
reg  [INTB-1:0]     next_int_flags;

always @* begin
    next_int_flags  = int_flags;

    if(csr_cmd_valid && csr_cmd_write && csr_addr == REG_INT_FLAGS) begin
        // clear on write of 1
        next_int_flags  = next_int_flags & ~csr_cmd_data[INTB-1:0];
    end

    if(set_disabled)        next_int_flags[0]   = 1'b1;
    if(set_axi_error)       next_int_flags[1]   = 1'b1;
    if(set_ack_overflow)    next_int_flags[2]   = 1'b1;
    if(set_fifo_overflow)   next_int_flags[3]   = 1'b1;
    if(set_fifo_empty)      next_int_flags[4]   = 1'b1;
    if(set_fifo_half_empty) next_int_flags[5]   = 1'b1;
    if(set_rows_completed)  next_int_flags[6]   = 1'b1;
    if(set_bufs_completed)  next_int_flags[7]   = 1'b1;
    if(set_row_start)       next_int_flags[8]   = 1'b1;
    if(set_row_done)        next_int_flags[9]   = 1'b1;
    if(set_frame_start)     next_int_flags[10]  = 1'b1;
    if(set_frame_done)      next_int_flags[11]  = 1'b1;
    if(set_buffer_done)     next_int_flags[12]  = 1'b1;
end

always @(posedge csr_clk) begin
    if(csr_rst) begin
        int_flags   <= 0;
        int_select  <= 0;
        csr_int     <= 1'b0;
    end else begin
        csr_int     <= |(next_int_flags & int_select);
        int_flags   <= next_int_flags;
        if(csr_cmd_valid && csr_cmd_write && csr_addr == REG_INT_SELECT) begin
            int_select  <= csr_cmd_data[INTB-1:0];
        end
    end
end

// ** rows/buffers completed **

reg  [ABITS-1:0]    rows_completed_thresh;
reg  [ABITS-1:0]    rows_completed;
reg  [ABITS-1:0]    next_rows_completed;
assign              set_rows_completed  = (rows_completed == rows_completed_thresh);

always @* begin
    next_rows_completed = rows_completed;
    if(csr_cmd_valid && !csr_cmd_write && csr_addr == REG_ROWS_COMPLETED) begin
        next_rows_completed = 0;
    end
    if(set_row_done) begin
        next_rows_completed = next_rows_completed + 1;
    end
end

reg  [ABITS-1:0]    bufs_completed_thresh;
reg  [ABITS-1:0]    bufs_completed;
reg  [ABITS-1:0]    next_bufs_completed;
assign              set_bufs_completed  = (bufs_completed == bufs_completed_thresh);

always @* begin
    next_bufs_completed = bufs_completed;
    if(csr_cmd_valid && !csr_cmd_write && csr_addr == REG_BUFFERS_COMPLETED) begin
        next_bufs_completed = 0;
    end
    if(set_buffer_done) begin
        next_bufs_completed = next_bufs_completed + 1;
    end
end

always @(posedge csr_clk) begin
    if(csr_rst_out) begin
        rows_completed  <= 0;
        bufs_completed  <= 0;
    end else begin
        rows_completed  <= next_rows_completed;
        bufs_completed  <= next_bufs_completed;
    end
end

always @(posedge csr_clk) begin
    if(csr_rst) begin
        rows_completed_thresh   <= 1;
        bufs_completed_thresh   <= 1;
    end else if(csr_cmd_valid && csr_cmd_write) begin
        if(csr_addr == REG_ROWS_THRESH) begin
            rows_completed_thresh   <= csr_cmd_data[ABITS-1:0];
        end
        if(csr_addr == REG_BUFFERS_THRESH) begin
            bufs_completed_thresh   <= csr_cmd_data[ABITS-1:0];
        end
    end
end

// ** other config registers **
// (only writeable when !ctrl_enable)

reg                 auto_mode;
reg                 clear_fifo;
wire [31:0]         csr_config      = { 31'd0, auto_mode };

reg  [ACKS:0]       ack_select; // 1 extra for internal ACK client

reg  [XBITS-1:0]    pixels_per_row;
reg  [YBITS-1:0]    rows_per_frame;
reg  [BLEN-1:0]     bytes_per_row;
reg  [AXI_ADDR-1:0] row_step;
reg  [YBITS-1:0]    rows_per_buffer;

always @(posedge csr_clk) begin
    if(csr_rst) begin
        auto_mode       <= 1'b0;
        clear_fifo      <= 1'b0;
        pixels_per_row  <= 0;
        rows_per_frame  <= 0;
        bytes_per_row   <= 0;
        rows_per_buffer <= 0;
    end else begin
        clear_fifo      <= ctrl_enable && !next_ctrl_enable;
        if(!ctrl_enable && csr_cmd_valid && csr_cmd_write) begin
            if(csr_addr == REG_CONFIG) begin
                auto_mode   <= csr_cmd_data[0];
                clear_fifo  <= csr_cmd_data[1];
            end
            if(csr_addr == REG_ACK_SELECT) begin
                ack_select  <= {csr_cmd_data[31],csr_cmd_data[ACKS-1:0]};
            end
            if(csr_addr == REG_PIXELS_PER_ROW) begin
                pixels_per_row  <= csr_cmd_data[XBITS-1:0];
            end
            if(csr_addr == REG_ROWS_PER_FRAME) begin
                rows_per_frame  <= csr_cmd_data[YBITS-1:0];
            end
            if(csr_addr == REG_BYTES_PER_PIXEL) begin
                // TODO
            end
            if(csr_addr == REG_BYTES_PER_ROW) begin
                bytes_per_row   <= csr_cmd_data[BLEN-1:0];
            end
            if(csr_addr == REG_ROW_STEP) begin
                row_step        <= csr_cmd_data[AXI_ADDR-1:0];
            end
            if(csr_addr == REG_ROWS_PER_BUFFER) begin
                rows_per_buffer <= csr_cmd_data[YBITS-1:0];
            end
        end
    end
end

// ** register read mux **

wire [AF_ADDR:0]    af_free;

wire [ACKS:0]       ack_status;
wire [ACKS:0]       ack_overflow;

wire [31:0]         csr_ack_rows;
wire [31:0]         csr_ack_select  = {ack_select[ACKS],{(31-ACKS){1'b0}},ack_select[ACKS-1:0]};
wire [31:0]         csr_ack_status  = {ack_status[ACKS],{(31-ACKS){1'b0}},ack_status[ACKS-1:0]};

always @(posedge csr_clk) begin
    csr_rsp_valid   <= 1'b0;
    csr_rsp_error   <= 1'b0;
    csr_rsp_data    <= 0;
    if(!csr_rst && csr_cmd_valid) begin
        csr_rsp_valid   <= 1'b1;
        if(!csr_cmd_write) begin
            // read
            case(csr_addr)
                REG_CORE_MAGIC:         csr_rsp_data            <= CORE_MAGIC;
                REG_CORE_VERSION:       csr_rsp_data            <= CORE_VERSION;
                REG_CORE_INTERFACE:     csr_rsp_data            <= CORE_INTERFACE;
                REG_CORE_INSTANCE:      csr_rsp_data            <= CORE_INSTANCE;
                REG_CONTROL:            csr_rsp_data            <= csr_control;
                REG_STATUS:             csr_rsp_data            <= csr_status;
                REG_FIFO_FREE:          csr_rsp_data[AF_ADDR:0] <= af_free;
                REG_ROWS_COMPLETED:     csr_rsp_data[ABITS-1:0] <= rows_completed;
                REG_ROWS_THRESH:        csr_rsp_data[ABITS-1:0] <= rows_completed_thresh;
                REG_BUFFERS_COMPLETED:  csr_rsp_data[ABITS-1:0] <= bufs_completed;
                REG_BUFFERS_THRESH:     csr_rsp_data[ABITS-1:0] <= bufs_completed_thresh;
                REG_ACK_ROWS:           csr_rsp_data            <= csr_ack_rows;
                REG_INT_FLAGS:          csr_rsp_data[INTB-1:0]  <= int_flags;
                REG_INT_SELECT:         csr_rsp_data[INTB-1:0]  <= int_select;
                REG_CONFIG:             csr_rsp_data            <= csr_config;
                REG_ACK_SELECT:         csr_rsp_data            <= csr_ack_select;
                REG_ACK_STATUS:         csr_rsp_data            <= csr_ack_status;
                REG_PIXELS_PER_ROW:     csr_rsp_data[XBITS-1:0] <= pixels_per_row;
                REG_ROWS_PER_FRAME:     csr_rsp_data[YBITS-1:0] <= rows_per_frame;
                REG_BYTES_PER_PIXEL:    csr_rsp_data            <= BYTES_PER_PIXEL;     // TODO
                REG_BYTES_PER_ROW:      csr_rsp_data[BLEN-1:0]  <= bytes_per_row;
                REG_ROW_STEP:           csr_rsp_data[AXI_ADDR-1:0] <= row_step;
                REG_ROWS_PER_BUFFER:    csr_rsp_data[YBITS-1:0] <= rows_per_buffer;
                default:                csr_rsp_data            <= 0;
            endcase
        end
    end
end


// ** enable control **

localparam      ST_DISABLED     = 2'd0,
                ST_ENABLING     = 2'd1,
                ST_ENABLED      = 2'd2,
                ST_DISABLING    = 2'd3;

reg  [1:0]      en_st;
reg  [1:0]      next_en_st;

assign          csr_enabled         = enabled;

assign          csr_rst_out         = csr_rst || !enabled;

wire            obs_axi_enabled;
wire            obs_px_enabled;

always @* begin
    next_en_st      = en_st;
    set_disabled    = 1'b0;

    if(en_st == ST_DISABLED && next_ctrl_enable) begin
        // enable requested
        next_en_st      = ST_ENABLING;
    end
    if(en_st == ST_ENABLING) begin
        if(!next_ctrl_enable) begin
            // disabled while trying to enable..
            next_en_st      = ST_DISABLING;
        end else if(obs_axi_enabled && obs_px_enabled) begin
            // enable complete
            next_en_st      = ST_ENABLED;
        end
    end
    if(en_st == ST_ENABLED && !next_ctrl_enable) begin
        // disable requested
        next_en_st      = ST_DISABLING;
    end
    if(en_st == ST_DISABLING && !obs_axi_enabled && !obs_px_enabled) begin
        // disable complete
        next_en_st      = ST_DISABLED;
        set_disabled    = 1'b1;
    end
end

always @(posedge csr_clk) begin
    if(csr_rst) begin
        en_st       <= ST_DISABLED;
        disabled    <= 1'b1;
        enabled_pre <= 1'b0;
        enabled     <= 1'b0;
    end else begin
        en_st       <= next_en_st;
        disabled    <= (next_en_st == ST_DISABLED);
        enabled_pre <= (next_en_st == ST_ENABLED || next_en_st == ST_ENABLING);
        enabled     <= (next_en_st == ST_ENABLED);
    end
end


// ** address FIFO **

wire                af_rst          = csr_rst || clear_fifo;

wire                af_almost_empty;
wire                af_empty;
wire                af_pop;
wire [AXI_ADDR:0]   af_rd_data;

wire                af_full;

reg                 af_push;
reg  [AXI_ADDR:0]   af_wr_data;

wire                af_push_pre         = (csr_cmd_valid && csr_cmd_write && csr_addr == REG_FIFO);

always @(posedge csr_clk) begin
    if(enabled && auto_mode) begin
        af_push     <= af_pop;
        af_wr_data  <= {1'b0,af_rd_data[AXI_ADDR-1:0]};
    end else begin
        af_push     <= af_push_pre && !af_full;
        af_wr_data  <= {1'b1,csr_cmd_data[AXI_ADDR-1:0]};
    end
end

assign              set_fifo_overflow   = af_push_pre && (af_full || (enabled && auto_mode));
assign              set_fifo_empty      = enabled && af_empty;
assign              set_fifo_half_empty = enabled && af_almost_empty;

dlsc_fifo #(
    .ADDR           ( AF_ADDR ),
    .DATA           ( 1+AXI_ADDR ),
    .ALMOST_EMPTY   ( (2**AF_ADDR)/2 ),
    .FREE           ( 1 ),
    .FAST_FLAGS     ( 1 )
) dlsc_fifo_buffer_addresses (
    .clk            ( csr_clk ),
    .rst            ( af_rst ),
    .wr_push        ( af_push ),
    .wr_data        ( af_wr_data ),
    .wr_full        ( af_full ),
    .wr_almost_full (  ),
    .wr_free        ( af_free ),
    .rd_pop         ( af_pop ),
    .rd_data        ( af_rd_data ),
    .rd_empty       ( af_empty ),
    .rd_almost_empty ( af_almost_empty ),
    .rd_count       (  )
);


// ** commands **

// DMA commands

wire                dma_ready;
reg                 dma_valid;
reg  [AXI_ADDR-1:0] dma_addr;
wire [BLEN-1:0]     dma_bytes       = bytes_per_row;

wire                obs_axi_cmd_done;
wire                dma_done        = obs_axi_cmd_done;

// Pixel pack commands

wire                pack_ready;
reg                 pack_valid;
wire [1:0]          pack_offset     = dma_addr[1:0];
wire [XBITS-1:0]    pack_words      = pixels_per_row;
/* verilator lint_off WIDTH */
wire [1:0]          pack_bpw        = BYTES_PER_PIXEL-1;
/* verilator lint_on WIDTH */

wire                ack_init        = WRITER && af_rd_data[AXI_ADDR];   // 1st use of a buffer doesn't need to wait for reader
wire                ack_okay        = ack_init || &ack_status;

reg [YBITS-1:0]     buf_row;
reg                 buf_row_first;
reg                 buf_row_last;

reg [YBITS-1:0]     frm_row;
reg                 frm_row_first;
reg                 frm_row_last;

wire                cmd_update      = enabled && !af_empty && ack_okay && !dma_valid && !pack_valid;

// pop buffer's address when done creating commands for it
assign              af_pop          = cmd_update && buf_row_last;

always @(posedge csr_clk) begin
    if(!enabled) begin
        dma_valid   <= 1'b0;
        pack_valid  <= 1'b0;
    end else begin
        if(dma_ready) begin
            dma_valid   <= 1'b0;
        end
        if(pack_ready) begin
            pack_valid  <= 1'b0;
        end
        if(cmd_update) begin
            dma_valid   <= 1'b1;
            pack_valid  <= 1'b1;
        end
    end
end

always @(posedge csr_clk) begin
    if(cmd_update) begin
        if(buf_row_first) begin
            // grab new buffer address from FIFO
            dma_addr    <= af_rd_data[AXI_ADDR-1:0];
        end else begin
            // advance to next row
            dma_addr    <= dma_addr + row_step;
        end
    end
end

always @(posedge csr_clk) begin
    if(!enabled) begin
        buf_row         <= 1;
        buf_row_first   <= 1'b1;
        buf_row_last    <= (rows_per_buffer == 1);
        frm_row         <= 1;
        frm_row_first   <= 1'b1;
        frm_row_last    <= (rows_per_frame == 1);
    end else if(cmd_update) begin
        
        if(buf_row_last) begin
            buf_row         <= 1;
            buf_row_first   <= 1'b1;
            buf_row_last    <= (rows_per_buffer == 1);
        end else begin
            buf_row         <= buf_row + 1;
            buf_row_first   <= 1'b0;
            buf_row_last    <= ( (buf_row+1) == rows_per_buffer );
        end

        if(frm_row_last) begin
            frm_row         <= 1;
            frm_row_first   <= 1'b1;
            frm_row_last    <= (rows_per_frame == 1);
        end else begin
            frm_row         <= frm_row + 1;
            frm_row_first   <= 1'b0;
            frm_row_last    <= ( (frm_row+1) == rows_per_frame );
        end
            
    end
end


// ** create flags **

reg [YBITS-1:0]     dma_buf_row;
reg                 dma_buf_row_last;

reg [YBITS-1:0]     dma_frm_row;
reg                 dma_frm_row_last;

always @(posedge csr_clk) begin
    // these flags only assert for 1 cycle
    set_row_start   <= 1'b0;
    set_row_done    <= 1'b0;
    set_frame_start <= 1'b0;
    set_frame_done  <= 1'b0;
    set_buffer_done <= 1'b0;
    csr_row_done    <= 0;
    if(!enabled) begin
        // reset these counters when disabled
        dma_buf_row     <= 1;
        dma_buf_row_last<= (rows_per_buffer == 1);
        dma_frm_row     <= 1;
        dma_frm_row_last<= (rows_per_frame == 1);
    end else begin
        if(cmd_update) begin
            set_row_start   <= 1'b1;
            set_frame_start <= frm_row_first;
        end
        if(dma_done) begin
            // finished writing row to memory
            set_row_done    <= 1'b1;
            csr_row_done    <= ack_select[ACKS-1:0];    // only send row_done acks to ones that are enabled
            if(dma_buf_row_last) begin
                // row was last in buffer
                set_buffer_done <= 1'b1;
                dma_buf_row     <= 1;
                dma_buf_row_last<= (rows_per_buffer == 1);
            end else begin
                dma_buf_row     <=  (dma_buf_row + 1);
                dma_buf_row_last<= ((dma_buf_row + 1) == rows_per_buffer);
            end
            if(dma_frm_row_last) begin
                // row was last in frame
                set_frame_done  <= 1'b1;
                dma_frm_row     <= 1;
                dma_frm_row_last<= (rows_per_frame == 1);
            end else begin
                dma_frm_row     <=  (dma_frm_row + 1);
                dma_frm_row_last<= ((dma_frm_row + 1) == rows_per_frame);
            end
        end
    end
end


// ** ack counter(s) **

assign          set_ack_overflow    = |ack_overflow;

genvar j;
generate

// external

for(j=0;j<ACKS;j=j+1) begin:GEN_ACKS

    reg [ABITS-1:0] ack_cnt;
    reg [ABITS  :0] next_ack_cnt;   // 1 extra bit to detect overflows
    
    reg             ack_valid_r;

    reg             ack_overflow_r;
    reg             next_overflow;

    assign          ack_status[j]   = ack_valid_r;
    assign          ack_overflow[j] = ack_overflow_r;

    always @* begin
        next_ack_cnt = {1'b0,ack_cnt};
        if(csr_row_ack[j]) begin
            next_ack_cnt = next_ack_cnt + 1;
        end
        if(cmd_update && !ack_init) begin
            next_ack_cnt = next_ack_cnt - 1;
        end
        next_overflow = ack_overflow_r || next_ack_cnt[ABITS];
    end

    always @(posedge csr_clk) begin
        if(!enabled || !ack_select[j]) begin
            ack_overflow_r  <= 1'b0;
            ack_valid_r     <= !ack_select[j];
            ack_cnt         <= 0;
        end else begin
            ack_overflow_r  <= next_overflow;
            ack_valid_r     <= (next_ack_cnt[ABITS-1:0] != 0) && !next_overflow;
            ack_cnt         <= next_ack_cnt[ABITS-1:0];
        end
    end

end

// internal

if(1) begin:GEN_ACKI
    
    reg [ABITS-1:0] ack_cnt;
    reg [ABITS  :0] next_ack_cnt;   // 1 extra bit to detect overflows
    
    reg             ack_valid_r;

    reg             ack_overflow_r;
    reg             next_overflow;

    assign          ack_status[ACKS]    = ack_valid_r;
    assign          ack_overflow[ACKS]  = ack_overflow_r;

    assign          csr_ack_rows        = { {(32-ABITS){1'b0}} , ack_cnt };

    always @* begin
        next_ack_cnt = {1'b0,ack_cnt};
        if(csr_cmd_valid && csr_cmd_write && csr_addr == REG_ACK_ROWS) begin
            next_ack_cnt = next_ack_cnt + csr_cmd_data[ABITS-1:0];
        end
        if(cmd_update && !ack_init) begin
            next_ack_cnt = next_ack_cnt - 1;
        end
        next_overflow = ack_overflow_r || next_ack_cnt[ABITS];
    end

    always @(posedge csr_clk) begin
        if(!enabled || !ack_select[ACKS]) begin
            ack_overflow_r  <= 1'b0;
            ack_valid_r     <= !ack_select[ACKS];
            ack_cnt         <= 0;
        end else begin
            ack_overflow_r  <= next_overflow;
            ack_valid_r     <= (next_ack_cnt[ABITS-1:0] != 0) && !next_overflow;
            ack_cnt         <= next_ack_cnt[ABITS-1:0];
        end
    end

end

endgenerate


// ** synchronization **

// CSR -> AXI

wire    axi_enabled_pre;
reg     axi_enabled;

dlsc_syncflop #(
    .BYPASS     ( CSR_DOMAIN == AXI_DOMAIN ),
    .DATA       ( 1 ),
    .RESET      ( 1'b0 )
) dlsc_syncflop_csr_to_axi (
    .in         ( enabled_pre ),
    .clk        ( axi_clk ),
    .rst        ( axi_rst ),
    .out        ( axi_enabled_pre )
);
    
dlsc_domaincross_rvh #(
    .BYPASS     ( CSR_DOMAIN == AXI_DOMAIN ),
    .DATA       ( AXI_ADDR+BLEN )
) dlsc_domaincross_rvh_csr_to_axi (
    .in_clk     ( csr_clk ),
    .in_rst     ( csr_rst_out ),
    .in_ready   ( dma_ready ),
    .in_valid   ( dma_valid ),
    .in_data    ( { dma_addr, dma_bytes } ),
    .out_clk    ( axi_clk ),
    .out_rst    ( axi_rst_out ),
    .out_ready  ( axi_cmd_ready ),
    .out_valid  ( axi_cmd_valid ),
    .out_data   ( { axi_cmd_addr, axi_cmd_bytes } )
);


// AXI -> CSR

dlsc_syncflop #(
    .BYPASS     ( AXI_DOMAIN == CSR_DOMAIN ),
    .DATA       ( 4 ),
    .RESET      ( 4'b0010 )
) dlsc_syncflop_axi_to_csr (
    .in         ( {     axi_busy,     axi_error,     axi_rst,     axi_enabled } ),
    .clk        ( csr_clk ),
    .rst        ( csr_rst ),
    .out        ( { obs_axi_busy, obs_axi_error, obs_axi_rst, obs_axi_enabled } )
);

dlsc_domaincross_pulse #(
    .BYPASS     ( AXI_DOMAIN == CSR_DOMAIN ),
    .DEPTH      ( AXI_MOT )
) dlsc_domaincross_pulse_axi_to_csr (
    .in_clk     ( axi_clk ),
    .in_rst     ( axi_rst_out ),
    .in_pulse   ( axi_cmd_done ),
    .out_clk    ( csr_clk ),
    .out_rst    ( csr_rst_out ),
    .out_pulse  ( obs_axi_cmd_done )
);


// CSR -> PX

wire    px_enabled;

dlsc_syncflop #(
    .BYPASS     ( CSR_DOMAIN == PX_DOMAIN ),
    .DATA       ( 1 ),
    .RESET      ( 1'b0 )
) dlsc_syncflop_csr_to_px (
    .in         ( enabled_pre ),
    .clk        ( px_clk ),
    .rst        ( px_rst ),
    .out        ( px_enabled )
);

dlsc_domaincross_rvh #(
    .BYPASS     ( CSR_DOMAIN == PX_DOMAIN ),
    .DATA       ( 4+XBITS )
) dlsc_domaincross_rvh_csr_to_px (
    .in_clk     ( csr_clk ),
    .in_rst     ( csr_rst_out ),
    .in_ready   ( pack_ready ),
    .in_valid   ( pack_valid ),
    .in_data    ( { pack_offset, pack_bpw, pack_words } ),
    .out_clk    ( px_clk ),
    .out_rst    ( px_rst_out ),
    .out_ready  ( px_cmd_ready ),
    .out_valid  ( px_cmd_valid ),
    .out_data   ( { px_cmd_offset, px_cmd_bpw, px_cmd_words } )
);


// PX -> CSR

dlsc_syncflop #(
    .BYPASS     ( PX_DOMAIN == CSR_DOMAIN ),
    .DATA       ( 2 ),
    .RESET      ( 2'b10 )
) dlsc_syncflop_px_to_csr (
    .in         ( { px_rst, px_enabled } ),
    .clk        ( csr_clk ),
    .rst        ( csr_rst ),
    .out        ( { obs_px_rst, obs_px_enabled } )
);


// ** Pixel Domain control **

assign px_rst_out = px_rst || !px_enabled;


// ** AXI Domain control **

assign axi_rst_out = axi_rst || !axi_enabled;

always @(posedge axi_clk) begin
    if(axi_rst) begin
        axi_enabled     <= 1'b0;
        axi_halt        <= 1'b1;
    end else begin
        if(axi_enabled_pre) begin
            // enable immediately
            axi_halt        <= 1'b0;
            axi_enabled     <= 1'b1;
        end
        if(!axi_enabled_pre) begin
            // halt before disabling
            axi_halt        <= 1'b1;
            if(axi_halt && !axi_busy) begin
                // disable once idle
                axi_enabled     <= 1'b0;
            end
        end
    end
end
        

endmodule

