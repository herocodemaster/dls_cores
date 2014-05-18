`timescale 1ns/1ps

module `DLSC_TB;

`include "dlsc_tb_top.vh"
`include "dlsc_util.vh"

localparam WIN2     = `PARAM_WIN_DELAY;
localparam DELAY    = `PARAM_PIPE_DELAY;
localparam META     = `PARAM_META;
localparam META1    = (META>0) ? META : 1;

reg                 rst     = 1'b1;
reg                 clk     = 1'b0;

initial forever #5 clk = !clk;

reg                 in_valid    = 1'b0;
reg                 in_unmask   = 1'b0;
reg  [META1-1:0]    in_meta     = 0;

wire                out_valid;
wire                out_unmask;
wire [META1-1:0]    out_meta;

// DUT

`DLSC_DUT #(
    .WIN_DELAY ( WIN2 ),
    .PIPE_DELAY ( DELAY ),
    .META ( META )
) dut (
    .clk ( clk ),
    .rst ( rst ),
    .in_valid ( in_valid ),
    .in_unmask ( in_unmask ),
    .in_meta ( in_meta ),
    .out_valid ( out_valid ),
    .out_unmask ( out_unmask ),
    .out_meta ( out_meta )
);

// Model

integer i;

wire                chk_valid;
wire                chk_unmask;
wire [META1-1:0]    chk_meta;

reg  [WIN2:0]       delay_ctr_unmask;
reg  [META1-1:0]    delay_ctr_meta [WIN2:0];

wire                delay_ctr_unmask_last   = delay_ctr_unmask[WIN2];
wire [META1-1:0]    delay_ctr_meta_last     = delay_ctr_meta[WIN2];

always @* begin
    delay_ctr_unmask[0] = in_unmask;
    delay_ctr_meta  [0] = (META>0) ? in_meta : 1'b0;
end

always @(posedge clk) begin
    if(rst) begin
        for(i=(WIN2-1);i>=0;i=i-1) begin
            delay_ctr_unmask[i+1]   <= 1'b0;
            delay_ctr_meta  [i+1]   <= {META1{1'bx}};
        end
    end else if(in_valid) begin
        for(i=(WIN2-1);i>=0;i=i-1) begin
            delay_ctr_unmask[i+1]   <= delay_ctr_unmask[i];
            delay_ctr_meta  [i+1]   <= delay_ctr_meta  [i];
        end
    end
end

reg  [DELAY:0]      delay_out_valid;
reg  [DELAY:0]      delay_out_unmask;
reg  [META1-1:0]    delay_out_meta [DELAY:0];

always @* begin
    delay_out_valid [0] = in_valid;
    delay_out_unmask[0] = delay_ctr_unmask_last;
    delay_out_meta  [0] = delay_ctr_meta_last;
end

always @(posedge clk) begin
    if(rst) begin
        for(i=(DELAY-1);i>=0;i=i-1) begin
            delay_out_valid [i+1]   <= 1'b0;
            delay_out_unmask[i+1]   <= 1'b0;
            delay_out_meta  [i+1]   <= {META1{1'bx}};
        end
    end else begin
        for(i=(DELAY-1);i>=0;i=i-1) begin
            delay_out_valid [i+1]   <= delay_out_valid [i];
            delay_out_unmask[i+1]   <= delay_out_unmask[i];
            delay_out_meta  [i+1]   <= delay_out_meta  [i];
        end
    end
end

assign chk_valid    = delay_out_valid [DELAY];
assign chk_unmask   = delay_out_unmask[DELAY];
assign chk_meta     = delay_out_meta  [DELAY];

// Checker

always @(negedge clk) begin
    if(out_valid !== chk_valid) begin
        `dlsc_error("out_valid (%0d) != chk_valid (%0d)", out_valid, chk_valid);
    end else begin
        `dlsc_okay("valid okay");
    end
    if(out_unmask !== chk_unmask) begin
        `dlsc_error("out_unmask (%0d) != chk_unmask (%0d)", out_unmask, chk_unmask);
    end else begin
        `dlsc_okay("unmask okay");
    end
    if(chk_meta !== {META1{1'bx}}) begin
        if(out_meta !== chk_meta) begin
            `dlsc_error("out_meta (%0d) != chk_meta (%0d)", out_meta, chk_meta);
        end else begin
            `dlsc_okay("meta okay");
        end
    end
end

// Stimulus

integer iter;
integer valid_rate, unmask_rate;

initial begin
    #100;
    @(posedge clk);

    iter = 0;
    repeat(100) begin
        iter = iter + 1;
        if((iter%10)==0) begin
            `dlsc_display("iteration %0d/100",iter);
        end

        // hold reset
        repeat(34) begin
            @(posedge clk);
            rst         <= 1'b1;
            in_valid    <= $random;
            in_unmask   <= $random;
            in_meta     <= $random;
        end
        @(posedge clk);
        rst         <= 1'b0;
        in_valid    <= 1'b0;
        in_unmask   <= 1'b0;
        in_meta     <= {META1{1'bx}};
        @(posedge clk);

        valid_rate  = (`dlsc_rand(0,99) < 50) ? 100 : `dlsc_rand(10,100);
        unmask_rate = (`dlsc_rand(0,99) < 50) ? 100 : `dlsc_rand(10,100);

        repeat(`dlsc_rand(100,10000)) begin
            if(`dlsc_rand(0,99) < valid_rate) begin
                in_valid    <= 1'b1;
                in_unmask   <= (`dlsc_rand(0,99) < unmask_rate);
                in_meta     <= $random;
            end else if(`dlsc_rand(0,99) < 30) begin
                in_valid    <= 1'b0;
                in_unmask   <= $random;
                in_meta     <= $random;
            end
            @(posedge clk);
        end

        in_valid    <= 1'b0;
        repeat(`dlsc_rand(1,1000)) @(posedge clk);
    end

    #1000;

    `dlsc_finish;
end


initial begin
    #20_000_000;
    `dlsc_error("watchdog timeout");

    `dlsc_finish;
end

endmodule

