`timescale 1ns/1ps

module `DLSC_TB;

`include "dlsc_tb_top.vh"
`include "dlsc_util.vh"

localparam CYCLES   = `PARAM_CYCLES;
localparam NB       = `PARAM_NB;
localparam DB       = `PARAM_DB;
localparam QB       = `PARAM_QB;
localparam QSKIP    = `PARAM_QSKIP;

localparam QSB      = QB + QSKIP;

localparam DELAY    = (CYCLES== 1) ? (QB+1) :   // fully pipelined
                      (CYCLES>=QB) ? (QB+2) :   // fully sequential
                                     (QB+4);    // hybrid

reg                 rst     = 1'b1;
reg                 clk     = 1'b0;

initial forever #5 clk = !clk;

reg                 in_valid    = 1'b0;
reg     [NB-1:0]    in_num      = 0;
reg     [DB-1:0]    in_den      = 0;

wire                out_valid;
wire    [QB-1:0]    out_quo;

// DUT

`DLSC_DUT #(
    .CYCLES ( CYCLES ),
    .NB ( NB ),
    .DB ( DB ),
    .QB ( QB ),
    .QSKIP ( QSKIP )
) dut (
    .clk ( clk ),
    .rst ( rst ),
    .in_valid ( in_valid ),
    .in_num ( in_num ),
    .in_den ( in_den ),
    .out_quo ( out_quo ),
    .out_valid ( out_valid )
);

// Checker

wire                chk_valid;
wire    [NB-1:0]    out_num;
wire    [DB-1:0]    out_den;

dlsc_pipedelay_valid #(
    .DATA       ( NB+DB ),
    .DELAY      ( DELAY )
) dlsc_pipedelay_valid (
    .clk        ( clk ),
    .rst        ( rst ),
    .in_valid   ( in_valid ),
    .in_data    ( { in_num, in_den } ),
    .out_valid  ( chk_valid ),
    .out_data   ( { out_num, out_den } )
);

reg [63:0] chk_num, chk_den, chk_quo;

always @* begin
    chk_num = out_num;
    chk_den = out_den;
    if(chk_den == 0) begin
        // divide-by-0
        chk_quo = {QB{1'b1}};
    end else begin
        if(QSB >= NB) begin
            chk_quo = (chk_num << (QSB-NB)) / chk_den;
        end else begin
            chk_quo = (chk_num >> (NB-QSB)) / chk_den;
        end
    end
end

always @(posedge clk) begin
    if(!rst) begin
        if(out_valid != chk_valid) begin
            `dlsc_error("out_valid (%0d) != chk_valid (%0d)", out_valid, chk_valid);
        end
        if(out_valid && (chk_den > 0)) begin
            if(out_quo == chk_quo) begin
                `dlsc_okay("quotient okay");
            end else begin
                `dlsc_error("%0d / %0d = %0d != %0d",chk_num,chk_den,chk_quo,out_quo);
            end
        end
    end
end

task div;
    input integer num;
    input integer den;
begin
    // clamp inputs
    num         = `dlsc_min(num, (2**NB)-1);
    den         = `dlsc_min(den, (2**DB)-1);
    if(QSKIP>0) begin
        den         = `dlsc_max(den, num >> (NB-1-QSKIP));
    end
    // initiate divide
    in_valid    <= 1'b1;
    in_num      <= num;
    in_den      <= den;
    @(posedge clk);
    in_valid    <= 1'b0;

    // wait minimum number of cycles
    repeat(CYCLES-1) @(posedge clk);

    // sometimes wait longer
    if(`dlsc_rand(0,7)==5) begin
        repeat(`dlsc_rand(1,30)) @(posedge clk);
    end
end
endtask

integer n, d;

initial begin
    #100;
    @(posedge clk);
    rst = 1'b0;
    @(posedge clk);

    div( 0, {DB{1'b1}} );
    div( 1, {DB{1'b1}} );

    div( {NB{1'b1}}, 1 );
    div( {NB{1'b1}}, {DB{1'b1}} );

    for(d=1;d<16;d=d+1) begin
        for(n=0;n<16;n=n+1) begin
            div( n, d );
        end
    end

    repeat(10) begin
        repeat(1000) begin
            case(`dlsc_rand(0,9))
                1:       n = 0;
                2:       n = 1;
                3:       n = ((2**NB)-1);
                4:       n = `dlsc_rand(0,15);
                default: n = `dlsc_rand(0,((2**NB)-1));
            endcase
            case(`dlsc_rand(0,9))
                2:       d = 1;
                3:       d = ((2**DB)-1);
                4:       d = `dlsc_rand(1,15);
                default: d = `dlsc_rand(1,((2**DB)-1));
            endcase
            div(n,d);
        end
        //`dlsc_display(".");
    end

    #1000;

    `dlsc_finish;
end


initial begin
    #5_000_000;
    `dlsc_error("watchdog timeout");

    `dlsc_finish;
end

endmodule

