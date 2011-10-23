
module dlsc_dma_command #(
    parameter ADDR      = 32,
    parameter LEN       = 4
) (
    // System
    input   wire                    clk,
    input   wire                    rst,

    // APB writes to FIFO
    input   wire                    apb_sel,
    input   wire                    apb_enable,
    input   wire                    apb_write,
    input   wire    [3:2]           apb_addr,
    input   wire    [31:0]          apb_wdata,

    // Control/status
    input   wire                    cmd_halt,
    output  reg     [1:0]           cmd_error,
    output  reg                     cmd_busy,

    // FIFO status
    output  wire    [7:0]           frd_free,
    output  wire                    frd_full,
    output  wire                    frd_empty,
    output  wire                    frd_almost_empty,
    output  wire    [7:0]           fwr_free,
    output  wire                    fwr_full,
    output  wire                    fwr_empty,
    output  wire                    fwr_almost_empty,

    // Command to read/write engines
    input   wire                    wr_cmd_almost_empty,
    output  wire                    wr_cmd_push,
    output  wire    [31:0]          wr_cmd_data,
    input   wire                    rd_cmd_almost_empty,
    output  wire                    rd_cmd_push,
    output  wire    [31:0]          rd_cmd_data,
    
    // AXI read command
    input   wire                    axi_ar_ready,
    output  reg                     axi_ar_valid,
    output  wire    [ADDR-1:0]      axi_ar_addr,
    output  wire    [LEN-1:0]       axi_ar_len,

    // AXI read data
    output  reg                     axi_r_ready,
    input   wire                    axi_r_valid,
    input   wire                    axi_r_last,
    input   wire    [31:0]          axi_r_data,
    input   wire    [1:0]           axi_r_resp
);

// limit reads to 16 beats (since that's all the command buffers can hold)
localparam LENI = (LEN>4) ? 4 : LEN;

localparam LSB = 2;


// States

localparam  ST_IDLE     = 0,
            ST_LO_SETUP = 1,
            ST_LO_READ  = 2,
            ST_LO_WRITE = 3,
            ST_HI_SETUP = 4,
            ST_HI_READ  = 5,
            ST_HI_WRITE = 6,
            ST_DATA     = 7,
            ST_POP      = 8;

reg  [3:0]      st;


// FIFO

reg             f_sel;
wire            f_pop           = (st == ST_POP);
wire            f_lsb           = (st == ST_HI_SETUP || st == ST_HI_READ || st == ST_HI_WRITE);
wire            f_wr_en         = (st == ST_LO_WRITE || st == ST_HI_WRITE);
reg  [31:0]     f_wr_data;
wire [31:0]     f_rd_data;
wire            stall;

dlsc_dma_command_fifo dlsc_dma_command_fifo_inst (
    .clk                ( clk ),
    .rst                ( rst ),
    .apb_sel            ( apb_sel ),
    .apb_enable         ( apb_enable ),
    .apb_write          ( apb_write ),
    .apb_addr           ( apb_addr[3:2] ),
    .apb_wdata          ( apb_wdata ),
    .sel                ( f_sel ),
    .pop                ( f_pop ),
    .lsb                ( f_lsb ),
    .wr_en              ( f_wr_en ),
    .wr_data            ( f_wr_data ),
    .rd_data            ( f_rd_data ),
    .stall              ( stall ),
    .frd_free           ( frd_free ),
    .frd_full           ( frd_full ),
    .frd_empty          ( frd_empty ),
    .frd_almost_empty   ( frd_almost_empty ),
    .fwr_free           ( fwr_free ),
    .fwr_full           ( fwr_full ),
    .fwr_empty          ( fwr_empty ),
    .fwr_almost_empty   ( fwr_almost_empty )
);


// AXI command

reg  [LENI-1:0] ar_len;
reg  [63:0]     ar_addr;

always @(posedge clk) begin
    if(!stall) begin
        if(st == ST_LO_READ) begin
            ar_len          <= ((2**LENI)-1) - f_rd_data[(LENI+LSB-1):LSB];
            ar_addr[31:0]   <= f_rd_data;
        end
        if(st == ST_HI_READ) begin
            ar_addr[63:32]  <= f_rd_data;
        end
    end
end

assign          axi_ar_len      = { {(LEN-LENI){1'b0}}, ar_len };
assign          axi_ar_addr     = { ar_addr[ADDR-1:LSB], {LSB{1'b0}} };

always @(posedge clk) begin
    if(rst) begin
        axi_ar_valid    <= 1'b0;
    end else begin
        if(axi_ar_ready) begin
            axi_ar_valid    <= 1'b0;
        end
        if(st == ST_HI_WRITE && !stall) begin
            axi_ar_valid    <= 1'b1;
        end
    end
end


// Incrementer

reg             carry;

always @(posedge clk) begin
    if(!stall) begin
        if(st == ST_LO_READ) begin
            { carry, f_wr_data } <=
                { {1'b0,f_rd_data[31:(LENI+LSB)]} + {{(32-LENI-LSB){1'b0}},1'b1}, {(LENI+LSB){1'b0}} };
        end
        if(st == ST_HI_READ) begin
            { carry, f_wr_data } <=
                { 1'b0, f_rd_data[31:0] } + { 32'd0, carry };
        end
    end
end


// Data parsing

localparam  DST_LEN     = 0,
            DST_ADDR32  = 1,
            DST_ADDR64  = 2,
            DST_TRIG    = 3;

reg  [1:0]      frd_dst;
reg             frd_dst_addr64;
reg             frd_dst_trig;
reg  [1:0]      fwr_dst;
reg             fwr_dst_addr64;
reg             fwr_dst_trig;

wire [1:0]      dst             = f_sel ? fwr_dst           : frd_dst;
wire            dst_addr64      = f_sel ? fwr_dst_addr64    : frd_dst_addr64;
wire            dst_trig        = f_sel ? fwr_dst_trig      : frd_dst_trig;

reg  [1:0]      next_dst;
reg             next_dst_addr64;
reg             next_dst_trig;

always @(posedge clk) begin
    if(rst) begin
        frd_dst     <= DST_LEN;
        fwr_dst     <= DST_LEN;
    end else if(axi_r_ready && axi_r_valid) begin
        if(!f_sel) begin
            frd_dst         <= next_dst;
            frd_dst_addr64  <= next_dst_addr64;
            frd_dst_trig    <= next_dst_trig;
        end else begin
            fwr_dst         <= next_dst;
            fwr_dst_addr64  <= next_dst_addr64;
            fwr_dst_trig    <= next_dst_trig;
        end
    end
end

reg             flush;
wire            next_flush      = flush || (dst == DST_LEN && axi_r_data == 0);

always @(posedge clk) begin
    if(st != ST_DATA) begin
        flush   <= 1'b0;
    end else if(axi_r_ready && axi_r_valid) begin
        flush   <= next_flush;
    end
end

always @* begin
    next_dst        = dst;
    next_dst_addr64 = dst_addr64;
    next_dst_trig   = dst_trig;

    if(st == ST_DATA) begin
        if(dst == DST_LEN) begin
            next_dst_addr64 = axi_r_data[0];
            next_dst_trig   = axi_r_data[1];
            if(!flush && axi_r_data != 0) begin
                next_dst        = DST_ADDR32;
            end
        end
        if(dst == DST_ADDR32) begin
            next_dst        = dst_addr64 ? DST_ADDR64 : (dst_trig ? DST_TRIG : DST_LEN);
        end
        if(dst == DST_ADDR64) begin
            next_dst        = dst_trig ? DST_TRIG : DST_LEN;
        end
        if(dst == DST_TRIG) begin
            next_dst        = DST_LEN;
        end
    end
end

wire [1:0]      next_cmd_error  = (axi_r_resp == 2'b00) ? cmd_error : axi_r_resp;

always @(posedge clk) begin
    if(rst) begin
        cmd_error   <= 2'b00;
    end else if(axi_r_ready && axi_r_valid) begin
        cmd_error   <= next_cmd_error;
    end
end

wire            cmd_push        = axi_r_ready && axi_r_valid && !next_flush && (next_cmd_error == 2'b00);
assign          rd_cmd_push     = cmd_push && !f_sel;
assign          rd_cmd_data     = axi_r_data;
assign          wr_cmd_push     = cmd_push && f_sel;
assign          wr_cmd_data     = axi_r_data;


// State machine

always @(posedge clk) begin
    if(rst) begin
        
        st          <= ST_IDLE;
        cmd_busy    <= 1'b0;
        f_sel       <= 1'b0;
        axi_r_ready <= 1'b0;

    end else begin

        if(!stall) begin
            if(st == ST_IDLE) begin
                cmd_busy        <= 1'b0;
            end
            if(st == ST_IDLE && !cmd_halt && (cmd_error == 2'b00)) begin
                if(!frd_empty && rd_cmd_almost_empty) begin
                    st              <= ST_LO_SETUP;
                    cmd_busy        <= 1'b1;
                    f_sel           <= 1'b0;
                end else if(!fwr_empty && wr_cmd_almost_empty) begin
                    st              <= ST_LO_SETUP;
                    cmd_busy        <= 1'b1;
                    f_sel           <= 1'b1;
                end
            end

            if(st == ST_LO_SETUP) begin
                st              <= ST_LO_READ;
            end
            if(st == ST_LO_READ) begin
                st              <= ST_LO_WRITE;
            end
            if(st == ST_LO_WRITE) begin
                st              <= ST_HI_SETUP;
            end

            if(st == ST_HI_SETUP) begin
                st              <= ST_HI_READ;
            end
            if(st == ST_HI_READ) begin
                st              <= ST_HI_WRITE;
            end
            if(st == ST_HI_WRITE) begin
                st              <= ST_DATA;
                axi_r_ready     <= 1'b1;
            end
            
            if(st == ST_POP) begin
                st              <= ST_IDLE;
            end
        end

        if(st == ST_DATA && axi_r_ready && axi_r_valid && axi_r_last) begin
            st              <= next_flush ? ST_POP : ST_IDLE;
            axi_r_ready     <= 1'b0;
        end

    end
end


endmodule

