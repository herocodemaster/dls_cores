
module dlsc_dma_registers #(
    parameter TRIG      = 8     // 1-16
) (
    // System
    input   wire                    clk,
    input   wire                    rst,
    output  wire                    rst_dma,

    // APB register access
    input   wire                    apb_sel,
    input   wire                    apb_enable,
    input   wire                    apb_write,
    input   wire    [5:2]           apb_addr,
    input   wire    [31:0]          apb_wdata,
    output  reg     [31:0]          apb_rdata,
    output  reg                     apb_ready,

    // Triggering
    input   wire    [TRIG-1:0]      trig_in,
    output  reg     [TRIG-1:0]      trig_in_ack,
    output  reg     [TRIG-1:0]      trig_out,
    input   wire    [TRIG-1:0]      trig_out_ack,

    // Interrupt output
    output  reg                     int_out,

    // Command block
    output  wire                    cmd_apb_sel,
    output  wire                    cmd_halt,
    input   wire    [1:0]           cmd_error,
    input   wire                    cmd_busy,

    // Command block FIFO status
    input   wire    [7:0]           frd_free,
    input   wire                    frd_full,
    input   wire                    frd_empty,
    input   wire                    frd_almost_empty,
    input   wire    [7:0]           fwr_free,
    input   wire                    fwr_full,
    input   wire                    fwr_empty,
    input   wire                    fwr_almost_empty,

    // Read block
    output  wire                    rd_halt,
    input   wire    [1:0]           rd_error,
    input   wire                    rd_busy,
    input   wire                    rd_cmd_done,
    output  wire    [TRIG-1:0]      rd_trig_in,
    input   wire    [TRIG-1:0]      rd_trig_ack,
    input   wire    [TRIG-1:0]      rd_trig_out,

    // Write block
    output  wire                    wr_halt,
    input   wire    [1:0]           wr_error,
    input   wire                    wr_busy,
    input   wire                    wr_cmd_done,
    output  wire    [TRIG-1:0]      wr_trig_in,
    input   wire    [TRIG-1:0]      wr_trig_ack,
    input   wire    [TRIG-1:0]      wr_trig_out
);

localparam  REG_CONTROL         = 4'h0,
            REG_STATUS          = 4'h1,
            REG_INT_FLAGS       = 4'h2,
            REG_INT_SELECT      = 4'h3,
            REG_COUNTS          = 4'h4,
            REG_TRIG_IN         = 4'h8,
            REG_TRIG_OUT        = 4'h9,
            REG_TRIG_IN_ACK     = 4'hA,
            REG_TRIG_OUT_ACK    = 4'hB,
            REG_FRD_LO          = 4'hC,
            REG_FRD_HI          = 4'hD,
            REG_FWR_LO          = 4'hE,
            REG_FWR_HI          = 4'hF;

// Registers
// 0x0: control             (RW)
//      0       : halt
//      1       : soft reset
// 0x1: status              (RO)
//      0       : cmd busy
//      7:6     : cmd error
//      8       : read busy
//      15:14   : read error
//      16      : write busy
//      23:22   : write error
// 0x2: interrupt flags     (RO)
//      15:0    : trig out
//      16      : frd_empty
//      17      : frd_almost_empty
//      18      : fwr_empty
//      19      : fwr_almost_empty
//      20      : read command completed
//      21      : write command completed
//      31      : error
// 0x3: interrupt select    (RW)
// 0x4: counts              (RO)
//      7:0     : read commands done (clear on read)
//      15:8    : write commands done (clear on read)
//      23:16   : frd_free
//      31:24   : fwr_free
// 0x8: trig in             (RW)
// 0x9: trig out            (RW)
// 0xA: trig in ack         (WO)
// 0xB: trig out ack        (WO)
// 0xC: frd push lo         (WO)
// 0xD: frd push hi         (WO)
// 0xE: fwr push lo         (WO)
// 0xF: fwr push hi         (WO)

assign          cmd_apb_sel     = apb_sel && (apb_addr[5:4] == 2'b11);


// Register some APB signals

wire            apb_read        = apb_sel && !apb_enable;
reg             apb_write_r;
reg  [5:2]      apb_addr_r;
reg  [31:0]     apb_wdata_r;

always @(posedge clk) begin
    if(rst) begin
        apb_ready       <= 1'b0;
        apb_write_r     <= 1'b0;
    end else begin
        apb_ready       <= (apb_sel && !apb_enable);
        apb_write_r     <= (apb_sel && !apb_enable && apb_write);
    end
end

always @(posedge clk) begin
    if(apb_sel) begin
        apb_addr_r      <= apb_addr;
        apb_wdata_r     <= apb_wdata;
    end
end


// Triggering

wire [TRIG-1:0] csr_trig_in_w       = (apb_write_r && apb_addr_r == REG_TRIG_IN     ) ? apb_wdata_r[TRIG-1:0] : 0;
wire [TRIG-1:0] csr_trig_out_w      = (apb_write_r && apb_addr_r == REG_TRIG_OUT    ) ? apb_wdata_r[TRIG-1:0] : 0;
wire [TRIG-1:0] csr_trig_in_ack_w   = (apb_write_r && apb_addr_r == REG_TRIG_IN_ACK ) ? apb_wdata_r[TRIG-1:0] : 0;
wire [TRIG-1:0] csr_trig_out_ack_w  = (apb_write_r && apb_addr_r == REG_TRIG_OUT_ACK) ? apb_wdata_r[TRIG-1:0] : 0;

reg  [TRIG-1:0] csr_trig_in_r;
reg  [TRIG-1:0] trig_in_r;

assign          rd_trig_in          = trig_in_r;
assign          wr_trig_in          = trig_in_r;

wire [TRIG-1:0] next_trig_in_ack    = csr_trig_in_ack_w | rd_trig_ack | wr_trig_ack;
wire [TRIG-1:0] next_trig_out       = (trig_out & ~(trig_out_ack | csr_trig_out_ack_w)) | csr_trig_out_w | rd_trig_out | wr_trig_out;
wire [TRIG-1:0] next_csr_trig_in    = (csr_trig_in_r & ~(csr_trig_in_ack_w | rd_trig_ack | wr_trig_ack)) | csr_trig_in_w;

always @(posedge clk) begin
    if(rst_dma) begin
        trig_in_ack     <= 0;
        trig_out        <= 0;
        csr_trig_in_r   <= 0;
        trig_in_r       <= 0;
    end else begin
        trig_in_ack     <= next_trig_in_ack;        
        trig_out        <= next_trig_out;
        csr_trig_in_r   <= next_csr_trig_in;
        trig_in_r       <= next_csr_trig_in | trig_in;
    end
end

wire [31:0]     csr_trig_in     = { {(32-TRIG){1'b0}}, trig_in_r };
wire [31:0]     csr_trig_out    = { {(32-TRIG){1'b0}}, trig_out };


// Status

reg             error;

always @(posedge clk) begin
    if(rst_dma) begin
        error       <= 1'b0;
    end else begin
        if(cmd_error != 2'b00 || rd_error != 2'b00 || wr_error != 2'b00) begin
            error       <= 1'b1;
        end
    end
end

wire            busy            = cmd_busy || rd_busy || wr_busy;

reg  [31:0]     csr_status;

always @* begin
    csr_status          = 0;
    csr_status[0]       = cmd_busy;
    csr_status[7:6]     = cmd_error;
    csr_status[8]       = rd_busy;
    csr_status[15:14]   = rd_error;
    csr_status[16]      = wr_busy;
    csr_status[23:22]   = wr_error;
end


// Control

reg             halt;
reg             soft_rst_req;

reg             soft_rst;
assign          rst_dma         = rst || soft_rst;

wire            halt_i          = halt || soft_rst_req || error;
assign          cmd_halt        = halt_i;
assign          rd_halt         = halt_i;
assign          wr_halt         = halt_i;

always @(posedge clk) begin
    if(rst) begin
        halt            <= 1'b0;
        soft_rst_req    <= 1'b0;
        soft_rst        <= 1'b0;
    end else begin
        if(soft_rst_req && !soft_rst && !busy) begin
            soft_rst        <= 1'b1;
        end
        if(soft_rst) begin
            soft_rst_req    <= 1'b0;
            soft_rst        <= 1'b0;
        end
        if(apb_write_r && apb_addr_r == REG_CONTROL) begin
            halt            <= apb_wdata_r[0];
            soft_rst_req    <= apb_wdata_r[1] || soft_rst_req;
        end
    end
end

wire [31:0]     csr_control     = { 30'd0, soft_rst_req, halt_i };


// Counts

reg  [7:0]      cnt_read;
reg             cnt_read_zero;
reg  [7:0]      cnt_write;
reg             cnt_write_zero;

always @(posedge clk) begin
    if(rst) begin
        cnt_read        <= 0;
        cnt_read_zero   <= 1'b1;
        cnt_write       <= 0;
        cnt_write_zero  <= 1'b1;
    end else begin
        if(apb_read && apb_addr == REG_COUNTS) begin
            cnt_read        <= rd_cmd_done ?    1 :    0;
            cnt_read_zero   <= rd_cmd_done ? 1'b0 : 1'b1;
            cnt_write       <= wr_cmd_done ?    1 :    0;
            cnt_write_zero  <= wr_cmd_done ? 1'b0 : 1'b1;
        end else begin
            if(rd_cmd_done && !(&cnt_read)) begin
                cnt_read        <= cnt_read + 1;
                cnt_read_zero   <= 1'b0;
            end
            if(wr_cmd_done && !(&cnt_write)) begin
                cnt_write       <= cnt_write + 1;
                cnt_write_zero  <= 1'b0;
            end
        end
    end
end

wire [31:0]     csr_counts      = { fwr_free, frd_free, cnt_write, cnt_read };


// Interrupts

reg  [31:0]     csr_int_flags;

always @* begin
    csr_int_flags           = 0;
    csr_int_flags[TRIG-1:0] = trig_out;
    csr_int_flags[19:16]    = { fwr_almost_empty, fwr_empty, frd_almost_empty, frd_empty };
    csr_int_flags[21:20]    = { !cnt_write_zero, !cnt_read_zero };
    csr_int_flags[31]       = error;
end

reg  [31:0]     csr_int_select;

always @(posedge clk) begin
    if(rst_dma) begin
        int_out     <= 1'b0;
    end else begin
        int_out     <= |(csr_int_flags & csr_int_select);
    end
end

always @(posedge clk) begin
    if(rst) begin
        csr_int_select  <= 0;
    end else begin
        if(apb_write_r && apb_addr_r == REG_INT_SELECT) begin
            csr_int_select              <= 0;
            csr_int_select[TRIG-1:0]    <= apb_wdata_r[TRIG-1:0];
            csr_int_select[21:16]       <= apb_wdata_r[21:16];
            csr_int_select[31]          <= apb_wdata_r[31];
        end
    end
end


// CSR reads

always @(posedge clk) begin
    apb_rdata   <= 0;

    if(apb_read) begin
        case(apb_addr)
            REG_CONTROL:        apb_rdata <= csr_control;
            REG_STATUS:         apb_rdata <= csr_status;
            REG_INT_FLAGS:      apb_rdata <= csr_int_flags;
            REG_INT_SELECT:     apb_rdata <= csr_int_select;
            REG_COUNTS:         apb_rdata <= csr_counts;
            REG_TRIG_IN:        apb_rdata <= csr_trig_in;
            REG_TRIG_OUT:       apb_rdata <= csr_trig_out;
            default:            apb_rdata <= 0;
        endcase
    end
end


endmodule

