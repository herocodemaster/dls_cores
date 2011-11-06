
module dlsc_apb_bfm #(
    parameter ADDR  = 32,
    parameter DATA  = 32,
    parameter STRB  = (DATA/8)
) (
    // System
    input   wire                    clk,
    input   wire                    rst,

    // APB
    output  reg     [ADDR-1:0]      apb_addr,
    output  reg                     apb_sel,
    output  reg                     apb_enable,
    output  reg                     apb_write,
    output  reg     [DATA-1:0]      apb_wdata,
    output  reg     [STRB-1:0]      apb_strb,
    input   wire                    apb_ready,
    input   wire    [DATA-1:0]      apb_rdata,
    input   wire                    apb_slverr
);

`include "dlsc_sim_top.vh"

initial begin
    apb_addr    <= 0;
    apb_sel     <= 1'b0;
    apb_enable  <= 1'b0;
    apb_write   <= 1'b0;
    apb_wdata   <= 0;
    apb_strb    <= 0;
end

task read;
    input [ADDR-1:0] addr;
    output [DATA-1:0] data;
begin
    // not initially synchronizing to clock, so back-to-back transactions are possible
    apb_addr    <= addr;
    apb_sel     <= 1'b1;
    apb_enable  <= 1'b0;
    apb_write   <= 1'b0;
    apb_strb    <= {STRB{1'b0}};
    @(posedge clk);
    apb_enable  <= 1'b1;
    #0; // let apb_enable prop (apb_ready may be combinational)
    while(!apb_ready) @(posedge clk);
    apb_sel     <= 1'b0;
    apb_enable  <= 1'b0;
    if(apb_slverr) begin
        `dlsc_warn("got slverr on read");
        data        = {DATA{1'bx}};
    end else begin
        data        = apb_rdata;
    end
end
endtask

task write;
    input [ADDR-1:0] addr;
    input [DATA-1:0] data;
begin
    // not initially synchronizing to clock, so back-to-back transactions are possible
    apb_addr    <= addr;
    apb_sel     <= 1'b1;
    apb_enable  <= 1'b0;
    apb_write   <= 1'b1;
    apb_wdata   <= data;
    apb_strb    <= {STRB{1'b1}};
    @(posedge clk);
    apb_enable  <= 1'b1;
    #0; // let apb_enable prop (apb_ready may be combinational)
    while(!apb_ready) @(posedge clk);
    apb_sel     <= 1'b0;
    apb_enable  <= 1'b0;
    if(apb_slverr) begin
        `dlsc_warn("got slverr on write");
    end
end
endtask

`include "dlsc_sim_bot.vh"

endmodule

