`timescale 1ns/1ps

module `DLSC_TB;

`include "dlsc_tb_top.vh"
`include "dlsc_util.vh"

`define STRINGIFY(d) `"d`"
localparam DEVICE   = `STRINGIFY(`PARAM_DEVICE);
localparam SIGNED   = `PARAM_SIGNED;
localparam DATA0    = `PARAM_DATA0;
localparam DATA1    = `PARAM_DATA1;
localparam OUT      = `PARAM_OUT;
localparam DATAF0   = `PARAM_DATAF0;
localparam DATAF1   = `PARAM_DATAF1;
localparam OUTF     = `PARAM_OUTF;
localparam CLAMP    = `PARAM_CLAMP;
localparam PIPELINE = `PARAM_PIPELINE;

localparam signed [63:0] OUTMAX = SIGNED ? ((64'sd1<<<(OUT-1))-1) : ((64'sd1<<<OUT)-1);
localparam signed [63:0] OUTMIN = SIGNED ? (-64'sd1-OUTMAX) : 0;

localparam signed [63:0] INMAX0 = SIGNED ? ((64'sd1<<<(DATA0-1))-1) : ((64'sd1<<<DATA0)-1);
localparam signed [63:0] INMIN0 = SIGNED ? (-64'sd1-INMAX0) : 0;

localparam signed [63:0] INMAX1 = SIGNED ? ((64'sd1<<<(DATA1-1))-1) : ((64'sd1<<<DATA1)-1);
localparam signed [63:0] INMIN1 = SIGNED ? (-64'sd1-INMAX1) : 0;

reg                 rst     = 1'b1;
reg                 clk     = 1'b0;

initial forever #5 clk = !clk;

reg                 clk_en      = 1'b1;
reg     [DATA0-1:0] dut_in0     = 0;
reg     [DATA1-1:0] dut_in1     = 0;

wire    [OUT-1:0]   dut_out;

// DUT

`DLSC_DUT #(
    .DEVICE ( DEVICE ),
    .SIGNED ( SIGNED ),
    .DATA0 ( DATA0 ),
    .DATA1 ( DATA1 ),
    .OUT ( OUT ),
    .DATAF0 ( DATAF0 ),
    .DATAF1 ( DATAF1 ),
    .OUTF ( OUTF ),
    .CLAMP ( CLAMP ),
    .PIPELINE ( PIPELINE ),
    .WARNINGS ( 0 )
) dut (
    .clk ( clk ),
    .clk_en ( clk_en ),
    .in0 ( dut_in0 ),
    .in1 ( dut_in1 ),
    .out ( dut_out )
);

// Checker

reg                 in_valid    = 1'b0;
wire                chk_valid;
wire signed [DATA0:0] out_in0;
wire signed [DATA1:0] out_in1;

assign out_in0[DATA0] = SIGNED ? out_in0[DATA0-1] : 1'b0;
assign out_in1[DATA1] = SIGNED ? out_in1[DATA1-1] : 1'b0;

dlsc_pipedelay_clken #(
    .DELAY      ( PIPELINE ),
    .DATA       ( DATA0+DATA1 )
) dlsc_pipedelay_clken (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .in_data    ( { dut_in0, dut_in1 } ),
    .out_data   ( { out_in0[DATA0-1:0], out_in1[DATA1-1:0] } )
);

dlsc_pipedelay_rst_clken #(
    .DELAY      ( PIPELINE ),
    .DATA       ( 1 ),
    .RESET      ( 1'b0 )
) dlsc_pipedelay_rst_clken (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .rst        ( rst ),
    .in_data    ( in_valid ),
    .out_data   ( chk_valid )
);

reg signed [63:0] chk_in0, chk_in1; // 32.32
reg signed [127:0] chk_outp; // 64.64
reg signed [63:0] chk_out; // (OUT-OUTF).OUTF
reg chk_ovf;

always @* begin
    chk_in0 = out_in0;
    chk_in1 = out_in1;
    chk_in0 = chk_in0 <<< (32-DATAF0);  // fixed 32.32 format
    chk_in1 = chk_in1 <<< (32-DATAF1);
    chk_outp = chk_in0 * chk_in1;
    chk_outp = chk_outp >>> (64-OUTF);
    chk_out = chk_outp;
    if(CLAMP) begin
        chk_ovf = 1'b0;
        if(chk_outp > OUTMAX) begin
            chk_out = OUTMAX;
        end else if(chk_outp < OUTMIN) begin
            chk_out = OUTMIN;
        end
    end else begin
        chk_ovf = (chk_outp > OUTMAX) || (chk_outp < OUTMIN);
    end
end

real rep_in0, rep_in1, rep_out, rep_chk;

always @* begin
    rep_in0 = SIGNED ? $signed(out_in0) : $unsigned(out_in0);
    rep_in1 = SIGNED ? $signed(out_in1) : $unsigned(out_in1);
    rep_out = SIGNED ? $signed(dut_out) : $unsigned(dut_out);
    rep_chk = chk_out;
    rep_in0 = rep_in0 / (2**DATAF0);
    rep_in1 = rep_in1 / (2**DATAF1);
    rep_out = rep_out / (2**OUTF);
    rep_chk = rep_chk / (2**OUTF);
end

always @(posedge clk) begin
    if(!rst) begin
        if(clk_en && chk_valid && !chk_ovf) begin
            if(dut_out == chk_out[OUT-1:0]) begin
                `dlsc_okay("out okay");
            end else begin
                `dlsc_error("out mismatch: %0f * %0f = %0f != %0f",rep_in0,rep_in1,rep_chk,rep_out);
            end
        end
    end
end

always @(posedge clk) begin
    if(`dlsc_rand(0,99) < 10) begin
        clk_en <= !clk_en;
    end
end

task mult;
    input signed [63:0] a;
    input signed [63:0] b;
begin
    // initiate multiply
    while(!clk_en) @(posedge clk);
    in_valid    <= 1'b1;
    dut_in0     <= a;
    dut_in1     <= b;
    @(posedge clk);
    while(!clk_en) @(posedge clk);
    in_valid    <= 1'b0;

    // sometimes wait longer
    if(`dlsc_rand(0,7)==5) begin
        repeat(`dlsc_rand(1,30)) @(posedge clk);
    end
end
endtask

reg signed [63:0] i, j;

initial begin
    #100;
    @(posedge clk);
    rst = 1'b0;
    @(posedge clk);
    clk_en = 1'b1;
    @(posedge clk);

    mult(0,0);
    mult(1,1);

    if(SIGNED) begin
        mult(0,-'sd1);
        mult(-'sd1,0);
        mult(1,-'sd1);
        mult(-'sd1,1);
    end

    mult(0,INMAX1);
    mult(INMAX0,0);
    mult(1,INMAX1);
    mult(INMAX0,1);
    mult(0,INMIN1);
    mult(INMIN0,0);
    mult(1,INMIN1);
    mult(INMIN0,1);
    mult(INMIN0,INMAX1);
    mult(INMAX0,INMIN1);
    mult(INMAX0,INMAX1);
    mult(INMAX0,INMAX1);

    repeat(10) begin
        repeat(2000) begin
            case(`dlsc_rand((SIGNED ? 0 : 2),11))
                0:       i = -'sd1;
                1:       i = `dlsc_rand(-'sd10,10);
                2:       i = INMIN0;
                3:       i = 0;
                4:       i = 1;
                5:       i = INMAX0;
                6:       i = `dlsc_rand(0,10);
                default: i = `dlsc_rand(INMIN0,INMAX0);
            endcase
            case(`dlsc_rand((SIGNED ? 0 : 2),11))
                0:       j = -'sd1;
                1:       j = `dlsc_rand(-'sd10,10);
                2:       j = INMIN1;
                3:       j = 0;
                4:       j = 1;
                5:       j = INMAX1;
                6:       j = `dlsc_rand(0,10);
                default: j = `dlsc_rand(INMIN1,INMAX1);
            endcase
            mult(i,j);
        end
        `dlsc_display(".");
    end

    #10000;

    `dlsc_finish;
end


initial begin
    #20_000_000;
    `dlsc_error("watchdog timeout");

    `dlsc_finish;
end

endmodule

