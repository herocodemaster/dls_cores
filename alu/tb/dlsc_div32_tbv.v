`timescale 1ns/1ps

module `DLSC_TB;

`include "dlsc_tb_top.vh"

//`define STRINGIFY(d) `"d`"
//localparam DEVICE       = `STRINGIFY(`PARAM_DEVICE);
localparam DEVICE = "GENERIC";

reg                 clk     = 1'b0;

initial forever #5 clk = !clk;

reg     [31:0]      dividend    = 0;
reg     [31:0]      divisor     = 0;
reg                 sign        = 0;
reg                 start       = 0;

wire                done;
wire    [31:0]      quotient;
wire    [31:0]      remainder;

// DUT

`DLSC_DUT #(
    .DEVICE ( DEVICE )
) dut (
    .clk ( clk ),
    .dividend ( dividend ),
    .divisor ( divisor ),
    .sign ( sign ),
    .start ( start ),
    .done ( done ),
    .quotient ( quotient ),
    .remainder ( remainder )
);

task div;
    input      [31:0] a;
    input      [31:0] b;
    input             s;
    reg signed [31:0] as;
    reg signed [31:0] bs;
    reg        [31:0] au;
    reg        [31:0] bu;
    reg signed [31:0] q;
    reg signed [31:0] r;
begin
    // initiate divide
    dividend<= a;
    divisor <= b;
    sign    <= s;
    start   <= 1;
    @(posedge clk);
    start   <= 0;

    // wait for result
    @(posedge clk);
    while(!done) @(posedge clk);

    // sometimes wait longer
    if(`dlsc_rand(0,9)==3) begin
        repeat(`dlsc_rand(1,10)) @(posedge clk);
    end

    // only check if not a divide-by-0 (undefined)
    if(b != 0) begin

        // compute expected result
        if(sign) begin
            // signed operands/result
            as      = a;
            bs      = b;
            q       = as / bs;
            r       = as % bs;
        end else begin
            // unsigned operands/result
            au      = a;
            bu      = b;
            q       = au / bu;
            r       = au % bu;
        end

        // check quotient
        if(q == quotient) begin
            `dlsc_okay("quotient");
        end else begin
            if(sign) begin
                `dlsc_error("%0d / %0d = %0d != %0d",as,bs,q,quotient);
            end else begin
                `dlsc_error("%0d / %0d = %0d != %0d",au,bu,q,quotient);
            end
        end

        // check remainder
        if(r == remainder) begin
            `dlsc_okay("remainder");
        end else begin
            if(sign) begin
                `dlsc_error("%0d %% %0d = %0d != %0d",as,bs,r,remainder);
            end else begin
                `dlsc_error("%0d %% %0d = %0d != %0d",au,bu,r,remainder);
            end
        end

    end
end
endtask

reg [63:0] o;

reg [31:0] a;
reg [31:0] b;

initial begin
    #100;
    @(posedge clk);
    
    div(32'h0000_0008,32'h0000_0003,0);
    div(32'h0000_0000,32'h0000_0001,0);
    div(32'h0000_0000,32'hFFFF_FFFF,0);
    div(32'h0000_0000,32'hFFFF_FFFF,1);
    div(32'hFFFF_FFFF,32'hFFFF_FFFF,0);
    div(32'hFFFF_FFFF,32'hFFFF_FFFF,1);
    div(32'h8000_0000,32'hFFFF_FFFF,1);
    div(32'h8000_0000,32'h7FFF_FFFF,1);
    div(32'h8000_0000,32'h8000_0000,1);
    div(32'h8000_0000,32'h0000_0001,1);
    div(32'h7FFF_FFFF,32'h7FFF_FFFF,1);

    repeat(10) begin
        repeat(2000) begin
            a = $random;
            b = $random;
            case(`dlsc_rand(0,7))
                1: a =  (a & 32'h0000_000F);    // small positive #
                2: a = ~(a & 32'h0000_000F);    // small negative #
                3: a =  (a | 32'h7FFF_FFF0);    // large positive #
                4: a = ~(a | 32'h7FFF_FFF0);    // large negative #
                5: a = 32'h1 << `dlsc_rand(0,31); // power-of-2
                default: ;
            endcase
            case(`dlsc_rand(0,7))
                1: b =  (b & 32'h0000_000F);    // small positive #
                2: b = ~(b & 32'h0000_000F);    // small negative #
                3: b =  (b | 32'h7FFF_FFF0);    // large positive #
                4: b = ~(b | 32'h7FFF_FFF0);    // large negative #
                5: b = 32'h1 << `dlsc_rand(0,31); // power-of-2
                default: ;
            endcase
            div(a,b,`dlsc_rand(0,1));
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

