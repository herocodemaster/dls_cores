
module dlsc_dma_command_fifo
(
    // System
    input   wire                    clk,
    input   wire                    rst,

    // APB
    input   wire                    apb_sel,
    input   wire                    apb_enable,
    input   wire                    apb_write,
    input   wire    [3:2]           apb_addr,
    input   wire    [31:0]          apb_wdata,

    // Control
    input   wire                    sel,                // 0: read, 1: write
    input   wire                    pop,
    input   wire                    lsb,
    input   wire                    wr_en,
    input   wire    [31:0]          wr_data,
    output  reg     [31:0]          rd_data,
    output  wire                    stall,

    // Status
    output  wire    [7:0]           frd_free,
    output  reg                     frd_full,
    output  reg                     frd_empty,
    output  reg                     frd_almost_empty,
    output  wire    [7:0]           fwr_free,
    output  reg                     fwr_full,
    output  reg                     fwr_empty,
    output  reg                     fwr_almost_empty
);

`include "dlsc_synthesis.vh"

localparam FIFA         = 4;
localparam DEPTH        = (2**FIFA)/2;
localparam ALMOST_EMPTY = DEPTH/2;


// State registers

reg  [FIFA-1:0] frd_free_i;
reg  [FIFA-1:1] frd_push_addr;
reg  [FIFA-1:1] frd_pop_addr;

reg  [FIFA-1:0] fwr_free_i;
reg  [FIFA-1:1] fwr_push_addr;
reg  [FIFA-1:1] fwr_pop_addr;

assign          frd_free        = { {(8-FIFA){1'b0}}, frd_free_i };
assign          fwr_free        = { {(8-FIFA){1'b0}}, fwr_free_i };


// APB

// address map:
// 3 2
// ----------------------
// 0 0    frd push lo
// 0 1    frd push hi
// 1 0    fwr push lo
// 1 1    fwr push hi

reg  [3:2]      apb_addr_r;
reg             apb_active;
assign          stall           = apb_active;

always @(posedge clk) begin
    // only active when writing to one of the FIFO push registers
    apb_active      <= apb_sel && !apb_enable && apb_write;
    apb_addr_r      <= apb_addr;
end


// State muxing

wire            sel_i           = apb_active ? apb_addr_r[3] : sel;
wire            lsb_i           = apb_active ? apb_addr_r[2] : lsb;

wire [FIFA-1:0] free            = sel_i ? fwr_free_i          : frd_free_i;
wire            full            = sel_i ? fwr_full            : frd_full;
wire            empty           = sel_i ? fwr_empty           : frd_empty;
wire            almost_empty    = sel_i ? fwr_almost_empty    : frd_almost_empty;
wire [FIFA-1:1] push_addr       = sel_i ? fwr_push_addr       : frd_push_addr;
wire [FIFA-1:1] pop_addr        = sel_i ? fwr_pop_addr        : frd_pop_addr;

wire [FIFA:0]   addr            = { sel_i, (apb_active ? push_addr : pop_addr), lsb_i };

wire [31:0]     wr_data_i       = apb_active ? apb_wdata     : wr_data;
wire            wr_en_i         = apb_active ? !full         : wr_en;
wire            push_i          = apb_active && !full && apb_addr_r[2]; // only push on write to hi
wire            pop_i           = !apb_active && pop;


// Next-state

reg  [FIFA-1:1] next_push_addr;
reg  [FIFA-1:1] next_pop_addr;
reg  [FIFA-1:0] next_free;
reg             next_full;
reg             next_empty;
reg             next_almost_empty;

always @* begin

    next_push_addr      = push_addr;
    next_pop_addr       = pop_addr;
    next_free           = free;
    next_full           = full;
    next_empty          = empty;
    next_almost_empty   = almost_empty;

    if(push_i) begin
        next_push_addr      = push_addr + 1;
        next_free           = free - 1;
        next_empty          = 1'b0;
        next_full           = (free == 1);
        if(free == ALMOST_EMPTY+1) begin
            next_almost_empty   = 1'b0;
        end
    end

    if(pop_i) begin
        next_pop_addr       = pop_addr + 1;
        next_free           = free + 1;
        next_empty          = (free == DEPTH-1);
        next_full           = 1'b0;
        if(free == ALMOST_EMPTY) begin
            next_almost_empty   = 1'b1;
        end
    end

end

always @(posedge clk) begin
    if(rst) begin
        frd_push_addr       <= 0;
        frd_pop_addr        <= 0;
        frd_free_i          <= DEPTH;
        frd_full            <= 1'b0;
        frd_empty           <= 1'b1;
        frd_almost_empty    <= 1'b1;
    end else if(!sel_i) begin
        frd_push_addr       <= next_push_addr;
        frd_pop_addr        <= next_pop_addr;
        frd_free_i          <= next_free;
        frd_full            <= next_full;
        frd_empty           <= next_empty;
        frd_almost_empty    <= next_almost_empty;
    end
end

always @(posedge clk) begin
    if(rst) begin
        fwr_push_addr       <= 0;
        fwr_pop_addr        <= 0;
        fwr_free_i          <= DEPTH;
        fwr_full            <= 1'b0;
        fwr_empty           <= 1'b1;
        fwr_almost_empty    <= 1'b1;
    end else if(sel_i) begin
        fwr_push_addr       <= next_push_addr;
        fwr_pop_addr        <= next_pop_addr;
        fwr_free_i          <= next_free;
        fwr_full            <= next_full;
        fwr_empty           <= next_empty;
        fwr_almost_empty    <= next_almost_empty;
    end
end


// Memory

`DLSC_LUTRAM reg [31:0] mem[(DEPTH*4)-1:0];

always @(posedge clk) begin
    if(!apb_active) begin
        rd_data     <= mem[addr];
    end
    if(wr_en_i) begin
        mem[addr]   <= wr_data_i;
    end
end


endmodule

