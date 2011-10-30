
module dlsc_fifo_async #(
    parameter DATA          = 8,    // width of data in FIFO
    parameter ADDR          = 4,    // depth of FIFO is 2**ADDR; width of free/count ports is ADDR+1
    parameter ALMOST_FULL   = 0,    // assert almost_full when <= ALMOST_FULL free spaces remain (0 makes it equivalent to full)
    parameter ALMOST_EMPTY  = 0,    // assert almost_empty when <= ALMOST_EMPTY valid entries remain (0 makes it equivalent to empty)
    parameter BRAM          = (((2**ADDR)*DATA)>=2048)  // use block RAMs (instead of LUTs)
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
    output  wire    [DATA-1:0]  rd_data,
    output  reg                 rd_empty,
    output  reg                 rd_almost_empty,
    output  reg     [ADDR  :0]  rd_count
);

`include "dlsc_synthesis.vh"

localparam DEPTH = (2**ADDR);

localparam [ADDR:0] MSB = {1'b1,{ADDR{1'b0}}};


// ** memory **

`DLSC_FANOUT_REG reg  [ADDR  :0] wr_addr_r;
`DLSC_FANOUT_REG reg             wr_push_r;
`DLSC_PIPE_REG   reg  [DATA-1:0] wr_data_r;
    
                 wire [ADDR  :0] rd_addr_next;
`DLSC_FANOUT_REG reg  [ADDR  :0] rd_addr;

generate
if(!BRAM) begin:GEN_LUTRAM

    `DLSC_LUTRAM     reg [DATA-1:0] mem[DEPTH-1:0];

    always @(posedge wr_clk) begin
        if(wr_push_r) begin
            mem[wr_addr_r[ADDR-1:0]] <= wr_data_r;
        end
    end

    assign rd_data = mem[rd_addr[ADDR-1:0]];

end else begin:GEN_BRAM

    dlsc_ram_dp #(
        .DATA           ( DATA ),
        .ADDR           ( ADDR ),
        .PIPELINE_WR    ( 0 ),
        .PIPELINE_RD    ( 1 ),
        .WARNINGS       ( 0 )
    ) dlsc_ram_dp_inst (
        .write_clk      ( wr_clk ),
        .write_en       ( wr_push_r ),
        .write_addr     ( wr_addr_r[ADDR-1:0] ),
        .write_data     ( wr_data_r ),
        .read_clk       ( rd_clk ),
        .read_en        ( 1'b1 ),
        .read_addr      ( rd_addr_next[ADDR-1:0] ),
        .read_data      ( rd_data )
    );

end
endgenerate


// ** input / write **

// rd_addr synced to wr domain
reg  [ADDR  :0] wr_rd_addr;

// write address
reg  [ADDR  :0] wr_addr_p1;
wire [ADDR  :0] wr_addr_p1_next     = wr_push ? wr_addr_p1 + 1 : wr_addr_p1;
reg  [ADDR  :0] wr_addr;
wire [ADDR  :0] wr_addr_next        = wr_push ? wr_addr_p1     : wr_addr;

// free
wire [ADDR  :0] wr_free_next        = wr_rd_addr -  wr_addr_next;
wire            wr_full_next        = wr_rd_addr == wr_addr_next;

always @(posedge wr_clk) begin
    if(wr_rst) begin
        wr_addr         <= 0;
        wr_addr_p1      <= 1;
        // full in reset
        wr_free         <= 0;
        wr_full         <= 1'b1;
    end else begin
        wr_addr         <= wr_addr_next;
        wr_addr_p1      <= wr_addr_p1_next;
        wr_free         <= wr_free_next;
        wr_full         <= wr_full_next;
    end
end

// re-register write signals for fanout control
always @(posedge wr_clk) begin
    wr_addr_r       <= wr_addr;
    wr_push_r       <= wr_push;
    wr_data_r       <= wr_data;
end

// almost full
generate
    if(ALMOST_FULL==0) begin:GEN_ALMOST_FULL_0
        always @(posedge wr_clk) begin
            if(wr_rst) begin
                wr_almost_full  <= 1'b1;
            end else begin
                wr_almost_full  <= wr_full_next;
            end
        end
    end else if(ALMOST_FULL >= DEPTH) begin:GEN_ALMOST_FULL_D
        always @(posedge wr_clk) begin
            if(wr_rst) begin
                wr_almost_full  <= 1'b1;
            end
        end
    end else begin:GEN_ALMOST_FULL

        reg  [ADDR  :0] wr_adaf_p1;
        wire [ADDR  :0] wr_adaf_p1_next     = wr_push ? wr_adaf_p1 + 1 : wr_adaf_p1;
        reg  [ADDR  :0] wr_adaf;
        wire [ADDR  :0] wr_adaf_next        = wr_push ? wr_adaf_p1     : wr_adaf;
        wire [ADDR  :0] wr_adaf_free        = wr_rd_addr -  wr_adaf_next;
        wire            wr_almost_full_next = wr_adaf_free[ADDR]; // almost full if result is negative

        always @(posedge wr_clk) begin
            if(wr_rst) begin
                /* verilator lint_off WIDTH */
                wr_adaf         <= ALMOST_FULL+1;
                wr_adaf_p1      <= ALMOST_FULL+2;
                /* verilator lint_on WIDTH */
                // full in reset
                wr_almost_full  <= 1'b1;
            end else begin
                wr_adaf         <= wr_adaf_next;
                wr_adaf_p1      <= wr_adaf_p1_next;
                wr_almost_full  <= wr_almost_full_next;
            end
        end

    end
endgenerate

// to gray

reg  [ADDR  :0] wr_addr_gray;
wire [ADDR  :0] wr_addr_gray_next;

dlsc_bin2gray #(ADDR+1) dlsc_bin2gray_wr (wr_addr,wr_addr_gray_next);

always @(posedge wr_clk) begin
    if(wr_rst) begin
        wr_addr_gray    <= 0;
    end else begin
        wr_addr_gray    <= wr_addr_gray_next;
    end
end

// from gray

wire [ADDR  :0] wr_rd_addr_gray;
wire [ADDR  :0] wr_rd_addr_next;

dlsc_gray2bin #(ADDR+1) dlsc_gray2bin_wr (wr_rd_addr_gray,wr_rd_addr_next);

always @(posedge wr_clk) begin
    if(wr_rst) begin
        wr_rd_addr      <= MSB;
    end else begin
        wr_rd_addr      <= wr_rd_addr_next^MSB;
    end
end


// ** output / read **

// wr_addr synced to rd domain
reg  [ADDR  :0] rd_wr_addr;

// read address
reg  [ADDR  :0] rd_addr_p1;
wire [ADDR  :0] rd_addr_p1_next     = rd_pop ? rd_addr_p1 + 1 : rd_addr_p1;
assign          rd_addr_next        = rd_pop ? rd_addr_p1     : rd_addr;

// count
wire [ADDR  :0] rd_count_next       = rd_wr_addr -  rd_addr_next;
wire            rd_empty_next       = rd_wr_addr == rd_addr_next;

always @(posedge rd_clk) begin
    if(rd_rst) begin
        rd_addr         <= 0;
        rd_addr_p1      <= 1;
        // empty in reset
        rd_count        <= 0;
        rd_empty        <= 1'b1;
    end else begin
        rd_addr         <= rd_addr_next;
        rd_addr_p1      <= rd_addr_p1_next;
        rd_count        <= rd_count_next;
        rd_empty        <= rd_empty_next;
    end
end

// almost empty
generate
    if(ALMOST_EMPTY==0) begin:GEN_ALMOST_EMPTY_0
        always @(posedge rd_clk) begin
            if(rd_rst) begin
                rd_almost_empty  <= 1'b1;
            end else begin
                rd_almost_empty  <= rd_empty_next;
            end
        end
    end else if(ALMOST_EMPTY >= DEPTH) begin:GEN_ALMOST_EMPTY_D
        always @(posedge rd_clk) begin
            if(rd_rst) begin
                rd_almost_empty  <= 1'b1;
            end
        end
    end else begin:GEN_ALMOST_EMPTY

        reg  [ADDR  :0] rd_adae_p1;
        wire [ADDR  :0] rd_adae_p1_next     = rd_pop ? rd_adae_p1 + 1 : rd_adae_p1;
        reg  [ADDR  :0] rd_adae;
        wire [ADDR  :0] rd_adae_next        = rd_pop ? rd_adae_p1     : rd_adae;
        wire [ADDR  :0] rd_adae_free        = rd_wr_addr -  rd_adae_next;
        wire            rd_almost_empty_next= rd_adae_free[ADDR]; // almost empty if result is negative

        always @(posedge rd_clk) begin
            if(rd_rst) begin
                /* verilator lint_off WIDTH */
                rd_adae         <= ALMOST_EMPTY+1;
                rd_adae_p1      <= ALMOST_EMPTY+2;
                /* verilator lint_on WIDTH */
                // empty in reset
                rd_almost_empty  <= 1'b1;
            end else begin
                rd_adae         <= rd_adae_next;
                rd_adae_p1      <= rd_adae_p1_next;
                rd_almost_empty  <= rd_almost_empty_next;
            end
        end

    end
endgenerate

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
wire [ADDR  :0] rd_wr_addr_next;

dlsc_gray2bin #(ADDR+1) dlsc_gray2bin_rd (rd_wr_addr_gray,rd_wr_addr_next);

always @(posedge rd_clk) begin
    if(rd_rst) begin
        rd_wr_addr      <= 0;
    end else begin
        rd_wr_addr      <= rd_wr_addr_next;
    end
end


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

