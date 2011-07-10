module dlsc_fifo #(
    parameter DATA          = 8,    // width of data in FIFO
    parameter ADDR          = 4,    // depth of FIFO is 2**ADDR
    parameter ALMOST_FULL   = 0,    // assert almost_full when <= ALMOST_FULL free spaces remain (0 makes it equivalent to full)
    parameter ALMOST_EMPTY  = 0,    // assert almost_empty when <= ALMOST_EMPTY valid entries remain (0 makes it equivalent to empty)
    parameter BRAM          = (DATA*(2**ADDR)>=4096) // use block RAM (instead of distributed RAM)
) (
    // system
    input   wire                clk,
    input   wire                rst,
    
    // input
    input   wire                wr_push,
    input   wire    [DATA-1:0]  wr_data,
    output  reg                 wr_full,
    output  wire                wr_almost_full,

    // output
    input   wire                rd_pop,
    output  wire    [DATA-1:0]  rd_data,
    output  reg                 rd_empty,
    output  wire                rd_almost_empty,
    output  wire    [ADDR:0]    rd_count
);

`include "dlsc_synthesis.vh"

localparam DEPTH    = (2**ADDR);


// ** storage memory **

reg  [ADDR-1:0] wr_addr;
wire [ADDR-1:0] rd_addr_next;
wire            rd_en;

generate
if(!BRAM) begin:GEN_LUTRAM

    `DLSC_LUTRAM reg [DATA-1:0] mem[DEPTH-1:0];

    reg  [DATA-1:0] mem_rd_data;
    assign          rd_data         = mem_rd_data;

    always @(posedge clk) begin
        if(wr_push) begin
            mem[wr_addr]    <= wr_data;
        end
    end
    always @(posedge clk) begin
        if(rd_en) begin
            mem_rd_data     <= mem[rd_addr_next];
        end
    end

end else begin:GEN_BRAM

    dlsc_ram_dp #(
        .DATA           ( DATA ),
        .ADDR           ( ADDR ),
        .PIPELINE_WR    ( 0 ),
        .PIPELINE_RD    ( 1 ),
        .WARNINGS       ( 0 )
    ) dlsc_ram_dp_inst (
        .write_clk      ( clk ),
        .write_en       ( wr_push ),
        .write_addr     ( wr_addr ),
        .write_data     ( wr_data ),
        .read_clk       ( clk ),
        .read_en        ( rd_en ),
        .read_addr      ( rd_addr_next ),
        .read_data      ( rd_data )
    );

end
endgenerate


// ** address generation **

reg  [ADDR-1:0] rd_addr;
reg  [ADDR-1:0] rd_addr_p1;

assign          rd_addr_next    = rd_pop ? rd_addr_p1 : rd_addr;

always @(posedge clk) begin
    if(rst) begin
        wr_addr     <= 0;
        rd_addr     <= 0;
        rd_addr_p1  <= 1;
    end else begin
        if(wr_push) begin
            wr_addr     <= wr_addr + 1;
        end
        if(rd_pop) begin
            rd_addr     <= rd_addr_p1;
            rd_addr_p1  <= rd_addr_p1 + 1;
        end
    end
end


// ** flags **

reg  [ADDR:0]   cnt;        // 1 extra bit, since we want to store [0,DEPTH] (not just DEPTH-1)
reg             almost_empty;
reg             almost_full;

assign          rd_almost_empty = (ALMOST_EMPTY==0) ? rd_empty : almost_empty;
assign          wr_almost_full  = (ALMOST_FULL ==0) ? wr_full  : almost_full;

assign          rd_count        = cnt;

always @(posedge clk) begin
    if(rst) begin
        wr_full         <= 1'b0;
        rd_empty        <= 1'b1;
        cnt             <= 0;
        almost_full     <= 1'b0;
        almost_empty    <= 1'b1;
    end else begin

        // pushed; count increments
        if( wr_push && !rd_pop) begin
            cnt             <= cnt + 1;
            wr_full         <= (cnt == (DEPTH-1));  // cnt will be DEPTH (full)
            if(cnt == (      ALMOST_EMPTY  )) almost_empty <= 1'b0;
            if(cnt == (DEPTH-ALMOST_FULL -1)) almost_full  <= 1'b1;
        end

        // popped; count decrements
        if(!wr_push &&  rd_pop) begin
            cnt             <= cnt - 1;
            wr_full         <= 1'b0;                // can't be full on pop
            if(cnt == (      ALMOST_EMPTY+1)) almost_empty <= 1'b1;
            if(cnt == (DEPTH-ALMOST_FULL   )) almost_full  <= 1'b0;
        end

        // special empty flag handling..
        // (since the RAM doesn't support simultaneously reading from the same
        //  address that is being written to)
        if(cnt == 1) begin
            if(rd_pop) begin
                rd_empty    <= 1'b1;
            end else begin
                rd_empty    <= 1'b0;
            end
        end

    end
end

// read on pop, or after first entry is written
assign          rd_en           = rd_pop || (rd_empty && cnt == 1);


// ** simulation checks **

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @(posedge clk) begin

    if( wr_push && !rd_pop && wr_full ) begin
        `dlsc_error("overflow");
    end
    if(             rd_pop && rd_empty) begin
        `dlsc_error("underflow");
    end

end

integer max_cnt;
always @(posedge clk) begin
    if(rst) begin
        max_cnt = 0;
    end else if(cnt > max_cnt) begin
        max_cnt = cnt;
    end
end

task report;
begin
    `dlsc_info("max usage: %0d%% (%0d/%0d)",((max_cnt*100)/DEPTH),max_cnt,DEPTH);
end
endtask

`include "dlsc_sim_bot.vh"
`endif

endmodule

