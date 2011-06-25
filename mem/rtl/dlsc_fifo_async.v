
module dlsc_fifo_async #(
    parameter DATA          = 8,    // width of data in FIFO
    parameter ADDR          = 4,    // depth of FIFO is 2**ADDR; width of free/count ports is ADDR+1
    parameter ALMOST_FULL   = 0,    // assert almost_full when ALMOST_FULL free spaces remain (0 makes it equivalent to full)
    parameter ALMOST_EMPTY  = 0     // assert almost_empty when ALMOST_EMPTY valid entries remain (0 makes it equivalent to empty)
) (

    // input
    input   wire                wr_clk,
    input   wire                wr_rst,
    input   wire                wr_push,
    input   wire    [DATA-1:0]  wr_data,
    output  reg                 wr_full,
    output  reg                 wr_almost_full,
    output  reg     [ADDR  :0]  wr_free,

    // output
    input   wire                rd_clk,
    input   wire                rd_rst,
    input   wire                rd_pop,
    output  reg     [DATA-1:0]  rd_data,
    output  reg                 rd_empty,
    output  reg                 rd_almost_empty,
    output  reg     [ADDR  :0]  rd_count
);

`include "dlsc_synthesis.vh"

localparam DEPTH = (2**ADDR);

localparam [ADDR:0] MSB = {1'b1,{ADDR{1'b0}}};


// ** memory **

reg  [ADDR  :0] wr_addr;

`DLSC_LUTRAM reg [DATA-1:0] mem[DEPTH-1:0];

always @(posedge wr_clk) begin
    if(wr_push) begin
        mem[wr_addr[ADDR-1:0]] <= wr_data;
    end
end

wire [ADDR  :0] rd_addr_next;

always @(posedge rd_clk) begin
    rd_data <= mem[rd_addr_next[ADDR-1:0]];
end


// ** input / write **

// rd_addr synced to wr domain
wire [ADDR  :0] wr_rd_addr;

wire [ADDR  :0] wr_addr_next        = wr_push ? (wr_addr + 1) : wr_addr;
wire [ADDR  :0] wr_free_next        = (wr_rd_addr ^ MSB) -  wr_addr_next;
wire            wr_full_next        = (wr_rd_addr ^ MSB) == wr_addr_next;
wire            wr_almost_full_next = (wr_free_next <= ALMOST_FULL);

always @(posedge wr_clk) begin
    if(wr_rst) begin
        wr_addr         <= 0;
        // full in reset
        wr_free         <= 0;
        wr_full         <= 1'b1;
        wr_almost_full  <= 1'b1;
    end else begin
        wr_addr         <= wr_addr_next;
        wr_free         <= wr_free_next;
        wr_full         <= wr_full_next;
        wr_almost_full  <= wr_almost_full_next;
    end
end

// to gray

reg  [ADDR  :0] wr_addr_gray;
wire [ADDR  :0] wr_addr_gray_next;

dlsc_bin2gray #(ADDR+1) dlsc_bin2gray_wr (wr_addr_next,wr_addr_gray_next);

always @(posedge wr_clk) begin
    if(wr_rst) begin
        wr_addr_gray    <= 0;
    end else begin
        wr_addr_gray    <= wr_addr_gray_next;
    end
end

// from gray

wire [ADDR  :0] wr_rd_addr_gray;

dlsc_gray2bin #(ADDR+1) dlsc_gray2bin_wr (wr_rd_addr_gray,wr_rd_addr);


// ** output / read **

// wr_addr synced to rd domain
wire [ADDR  :0] rd_wr_addr;

reg  [ADDR  :0] rd_addr;
assign          rd_addr_next        = rd_pop ? (rd_addr + 1) : rd_addr;
wire [ADDR  :0] rd_count_next       = rd_wr_addr -  rd_addr_next;
wire            rd_empty_next       = rd_wr_addr == rd_addr_next;
wire            rd_almost_empty_next= (rd_count_next <= ALMOST_EMPTY);

always @(posedge rd_clk) begin
    if(rd_rst) begin
        rd_addr         <= 0;
        rd_count        <= 0;
        rd_empty        <= 1'b1;
        rd_almost_empty <= 1'b1;
    end else begin
        rd_addr         <= rd_addr_next;
        rd_count        <= rd_count_next;
        rd_empty        <= rd_empty_next;
        rd_almost_empty <= rd_almost_empty_next;
    end
end

// to gray

reg  [ADDR  :0] rd_addr_gray;
wire [ADDR  :0] rd_addr_gray_next;

dlsc_bin2gray #(ADDR+1) dlsc_bin2gray_rd (rd_addr_next,rd_addr_gray_next);

always @(posedge rd_clk) begin
    if(rd_rst) begin
        rd_addr_gray    <= 0;
    end else begin
        rd_addr_gray    <= rd_addr_gray_next;
    end
end

// from gray

wire [ADDR  :0] rd_wr_addr_gray;

dlsc_gray2bin #(ADDR+1) dlsc_gray2bin_rd (rd_wr_addr_gray,rd_wr_addr);


// ** sync **

dlsc_syncflop #(
    .DATA       ( ADDR+1 )
) dlsc_syncflop_wr (
    .in         ( rd_addr_gray ),
    .clk        ( wr_clk ),
    .rst        ( wr_rst ),
    .out        ( wr_rd_addr_gray )
);

dlsc_syncflop #(
    .DATA       ( ADDR+1 )
) dlsc_syncflop_rd (
    .in         ( wr_addr_gray ),
    .clk        ( rd_clk ),
    .rst        ( rd_rst ),
    .out        ( rd_wr_addr_gray )
);


// ** simulation checks **

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @(posedge wr_clk) begin
    if(!wr_rst && wr_push && wr_full) begin
        `dlsc_error("overflow");
    end
end

always @(posedge rd_clk) begin
    if(!rd_rst && rd_pop && rd_empty) begin
        `dlsc_error("underflow");
    end
end

`include "dlsc_sim_bot.vh"
`endif


endmodule

