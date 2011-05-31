module dlsc_fifo #(
    parameter DATA          = 8,    // width of data in FIFO
    parameter DEPTH         = 16,   // depth of FIFO (doesn't have to be a power-of-2)
    parameter ALMOST_FULL   = 0,    // assert almost_full when ALMOST_FULL free spaces remain (0 makes it equivalent to full)
    parameter ALMOST_EMPTY  = 0     // assert almost_empty when ALMOST_EMPTY valid entries remain (0 makes it equivalent to empty)
) (
    // system
    input   wire                clk,
    input   wire                rst,
    
    // input
    input   wire                push_en,
    input   wire    [DATA-1:0]  push_data,

    // output
    input   wire                pop_en,
    output  wire    [DATA-1:0]  pop_data,

    // status
    output  reg                 empty,
    output  reg                 full,
    output  reg                 almost_empty,
    output  reg                 almost_full
);

`include "dlsc_synthesis.vh"
`include "dlsc_clog2.vh"

localparam ADDR     = `dlsc_clog2(DEPTH);
localparam POWER2   = (DEPTH == (2**ADDR)); // power-of-2 depth can simplify a few things

// ** storage memory **
reg [ADDR-1:0] wr_addr;
reg [ADDR-1:0] rd_addr;
`DLSC_LUTRAM reg [DATA-1:0] mem[DEPTH-1:0];

assign pop_data = mem[rd_addr];

always @(posedge clk) begin
    if(push_en) begin
        mem[wr_addr]    <= push_data;
    end
end

/* verilator lint_off WIDTH */

// pointer last flags (used for wrapping when DEPTH isn't a power-of-2)
reg wr_addr_last = 1'b0;
reg rd_addr_last = 1'b0;

generate if(!POWER2) begin:GEN_LASTS
    always @(posedge clk) begin
        if(rst) begin
            wr_addr_last    <= 1'b0;
        end else if(push_en) begin
            wr_addr_last    <= (wr_addr == (DEPTH-2));
        end
    end
    always @(posedge clk) begin
        if(rst) begin
            rd_addr_last    <= 1'b0;
        end else if(pop_en) begin
            rd_addr_last    <= (rd_addr == (DEPTH-2));
        end
    end
end endgenerate

// write pointer
wire wr_addr_rst = rst || (wr_addr_last && push_en);
always @(posedge clk) begin
    if(wr_addr_rst) begin
        wr_addr         <= 0;
    end else if(push_en) begin
        wr_addr         <= wr_addr + 1;
    end
end

// read pointer
wire rd_addr_rst = rst || (rd_addr_last && pop_en);
always @(posedge clk) begin
    if(rd_addr_rst) begin
        rd_addr         <= 0;
    end else if(pop_en) begin
        rd_addr         <= rd_addr + 1;
    end
end


// ** control **
reg [ADDR:0]    cnt;        // 1 extra bit, since we need to store [0,DEPTH] (not just DEPTH-1)

always @(posedge clk) begin
    if(rst) begin

        empty           <= 1'b1;
        full            <= 1'b0;
        almost_empty    <= 1'b1;
        almost_full     <= 1'b0;
        
        cnt             <= 0;

    end else begin

        // pushed; count increments
        if(push_en && !pop_en) begin
            cnt             <= cnt + 1;
            empty           <= 1'b0;                // can't be empty on push
            full            <= (cnt == (DEPTH-1));  // cnt will be DEPTH (full)
            if(cnt == (      ALMOST_EMPTY  )) almost_empty <= 1'b0;
            if(cnt == (DEPTH-ALMOST_FULL -1)) almost_full  <= 1'b1;
        end

        // popped; count decrements
        if(!push_en && pop_en) begin
            cnt             <= cnt - 1;
            empty           <= (cnt == 1);          // cnt will be 0 (empty)
            full            <= 1'b0;                // can't be full on pop
            if(cnt == (      ALMOST_EMPTY+1)) almost_empty <= 1'b1;
            if(cnt == (DEPTH-ALMOST_FULL   )) almost_full  <= 1'b0;
        end

    end
end

/* verilator lint_on WIDTH */


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @(posedge clk) begin

    if( push_en && !pop_en && full ) begin
        `dlsc_error("overflow");
    end
    if(             pop_en && empty) begin
        `dlsc_error("underflow");
    end

//    if(!rst) begin
//        if(full != (cnt == DEPTH)) begin
//            `dlsc_error("full flag mismatch");
//        end
//        if(empty != (cnt == 0)) begin
//            `dlsc_error("empty flag mismatch");
//        end
//        if(almost_full != (cnt >= (DEPTH-ALMOST_FULL))) begin
//            `dlsc_error("almost_full flag mismatch");
//        end
//        if(almost_empty != (cnt <= (ALMOST_EMPTY))) begin
//            `dlsc_error("almost_empty flag mismatch");
//        end
//    end

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

