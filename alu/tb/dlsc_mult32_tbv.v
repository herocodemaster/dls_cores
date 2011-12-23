`timescale 1ns/1ps

module `DLSC_TB;

`include "dlsc_tb_top.vh"

`define STRINGIFY(d) `"d`"
localparam DEVICE       = `STRINGIFY(`PARAM_DEVICE);
localparam REGISTER_IN  = `PARAM_REGISTER_IN;
localparam REGISTER_OUT = `PARAM_REGISTER_OUT;

reg                 clk     = 1'b0;

initial forever #5 clk = !clk;

reg     [31:0]      in0     = 0;
reg     [31:0]      in1     = 0;
reg                 sign    = 0;
reg                 start   = 0;

wire    [63:0]      out;
wire                done;
wire                done33;
wire                done16;

// DUT

`DLSC_DUT #(
    .DEVICE ( DEVICE ),
    .REGISTER_IN (REGISTER_IN),
    .REGISTER_OUT (REGISTER_OUT)
) dut (
    .clk ( clk ),
    .in0 ( in0 ),
    .in1 ( in1 ),
    .sign ( sign ),
    .start ( start ),
    .out ( out ),
    .done ( done ),
    .done33 ( done33 ),
    .done16 ( done16 )
);

task mult;
    input      [31:0] a;
    input      [31:0] b;
    input             s;
    output     [63:0] o;
    reg signed [31:0] as;
    reg signed [31:0] bs;
    reg        [31:0] au;
    reg        [31:0] bu;
    reg signed [63:0] m;
begin
    in0     <= a;
    in1     <= b;
    sign    <= s;
    start   <= 1;
    @(posedge clk);
    start   <= 0;
    @(posedge clk);
    while(!done) @(posedge clk);
    o       = out;
    if(sign) begin
        as      = a;
        bs      = b;
        m       = as * bs;
    end else begin
        au      = a;
        bu      = b;
        m       = au * bu;
    end
    if(m == out) begin
        `dlsc_okay("multiply");
    end else begin
        if(sign) begin
            `dlsc_error("%0d * %0d = %0d != %0d",as,bs,m,out);
        end else begin
            `dlsc_error("%0d * %0d = %0d != %0d",au,bu,m,out);
        end
    end
end
endtask

reg [63:0] o;

initial begin
    #100;
    @(posedge clk);

    mult(32'h0000_0000,32'h0000_0000,0,o);
    mult(32'hFFFF_FFFF,32'hFFFF_FFFF,0,o);
    mult(32'hFFFF_FFFF,32'hFFFF_FFFF,1,o);
    mult(32'h8000_0000,32'h7FFF_FFFF,1,o);
    mult(32'h8000_0000,32'h8000_0000,1,o);
    mult(32'h7FFF_FFFF,32'h7FFF_FFFF,1,o);

    repeat(10) begin
        repeat(1000) begin
            mult($random,$random,`dlsc_rand(0,1),o);
            if(`dlsc_rand(0,9)==7) begin
                repeat(`dlsc_rand(1,30)) @(posedge clk);
            end
        end
        `dlsc_display(".");
    end

    #100;

    `dlsc_finish;
end


initial begin
    #20_000_000;
    `dlsc_error("watchdog timeout");

    `dlsc_finish;
end

endmodule

