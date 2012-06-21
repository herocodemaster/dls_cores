
`timescale 1ns/1ps

module `DLSC_TB;

`include "dlsc_tb_top.vh"

localparam ADDR             = `PARAM_ADDR;
localparam DATA             = `PARAM_DATA;

integer i;

reg                 clk = 1'b0;
reg                 rst = 1'b1;

initial forever #5 clk = !clk;
    
wire                    csr_cmd_valid;
wire                    csr_cmd_write;
wire    [ADDR-1:0]      csr_cmd_addr;
wire    [DATA-1:0]      csr_cmd_data;
reg                     csr_rsp_valid;
reg                     csr_rsp_error;
reg     [DATA-1:0]      csr_rsp_data;

`DLSC_DUT #(
    .ADDR           ( ADDR ),
    .DATA           ( DATA )
) dut (
    .clk            ( clk ),
    .rst            ( rst ),
    .csr_cmd_valid  ( csr_cmd_valid ),
    .csr_cmd_write  ( csr_cmd_write ),
    .csr_cmd_addr   ( csr_cmd_addr ),
    .csr_cmd_data   ( csr_cmd_data ),
    .csr_rsp_valid  ( csr_rsp_valid ),
    .csr_rsp_error  ( csr_rsp_error ),
    .csr_rsp_data   ( csr_rsp_data )
);

localparam DEPTHB=8;
localparam DEPTH=(2**DEPTHB);
reg [DATA-1:0] mem [DEPTH-1:0];

always @(posedge clk) begin
    if(rst) begin
        for(i=0;i<DEPTH;i=i+1) begin
            mem[i] = i;
        end
        csr_rsp_valid   <= 1'b0;
        csr_rsp_error   <= 1'b0;
        csr_rsp_data    <= {DATA{1'b0}};
    end else begin
        csr_rsp_valid   <= 1'b0;
        csr_rsp_error   <= 1'b0;
        csr_rsp_data    <= {DATA{1'b0}};
        if(csr_cmd_valid) begin
            csr_rsp_valid   <= 1'b1;
            if(csr_cmd_write) begin
                mem[csr_cmd_addr[2+:DEPTHB]] <= csr_cmd_data;
            end else begin
                csr_rsp_data    <= mem[csr_cmd_addr[2+:DEPTHB]];
            end
        end
    end
end

reg [ADDR-1:0] addr;
reg [DATA-1:0] data;

initial begin
    rst     = 1'b1;
    #1000;
    @(posedge clk);
    rst     = 1'b0;
    @(posedge clk);

    repeat(1000) begin

        repeat(`dlsc_rand(0,10)) @(posedge clk);

        addr = 0;
        addr[2+:DEPTHB] = $random;

        if(`dlsc_rand(0,1) == 0) begin
            data = $random;
            dut.write(addr,data);
            if(mem[addr[2+:DEPTHB]] != data) begin
                `dlsc_error("write failed");
            end else begin
                `dlsc_okay("write succeeded");
            end
        end else begin
            dut.read(addr,data);
            if(mem[addr[2+:DEPTHB]] != data) begin
                `dlsc_error("read failed");
            end else begin
                `dlsc_okay("read succeeded");
            end
        end

    end

    `dlsc_finish;
end

initial begin
    #1000000;
    `dlsc_error("watchdog timeout");

    `dlsc_finish;
end

endmodule

