
module dlsc_uart_tx_core #(
    parameter START         = 1,
    parameter STOP          = 1,
    parameter DATA          = 8,
    parameter PARITY        = 0,    // 0 = NONE, 1 = ODD, 2 = EVEN
    parameter OVERSAMPLE    = 1
) (
    // system
    input   wire                clk,
    input   wire                clk_en,         // must enable at baud rate
    input   wire                rst,

    // uart pins
    output  reg                 tx,
    output  reg                 tx_en,

    // transmit data
    output  reg                 ready,
    input   wire                valid,
    input   wire    [DATA-1:0]  data
);

`include "dlsc_clog2.vh"

localparam PARITY_BITS  = (PARITY>0)?1:0;
localparam BITS         = (START+STOP+DATA+PARITY_BITS);

wire clk_en_div;

reg [BITS-1:0] sr;

wire sr_empty   = (sr == {BITS{1'b0}});
wire parity     = (PARITY == 1) ? ~^data : ^data;

always @(posedge clk) begin
    if(rst) begin
        
        tx      <= 1'b1;
        tx_en   <= 1'b0;
        ready   <= 1'b0;

        sr      <= 0;

    end else begin

        ready   <=  sr_empty;

        if(ready && valid) begin
            ready   <= 1'b0;
            sr      <= { {STOP{1'b1}}, {PARITY_BITS{parity}}, data, {START{1'b0}} };
        end

        if(clk_en_div) begin
            if(sr_empty) begin
                tx      <= 1'b1;
                tx_en   <= 1'b0;
            end else begin
                {sr,tx} <= {1'b0,sr};
                tx_en   <= 1'b1;
            end
        end

    end
end

localparam OSBITS   = `dlsc_clog2(OVERSAMPLE);

generate
    if(OVERSAMPLE <= 1) begin:GEN_NOOVERSAMPLE
        
        assign clk_en_div = clk_en;

    end else begin:GEN_OVERSAMPLE

        reg [OSBITS-1:0] oscnt;
        reg              osen;

        assign clk_en_div = osen;

        always @(posedge clk) begin
            if(rst) begin
                oscnt       <= 0;
                osen        <= 1'b0;
            end else begin
                osen        <= 1'b0;
                if(clk_en) begin
                    oscnt       <= oscnt + 1;
/* verilator lint_off WIDTH */
                    if(oscnt == (OVERSAMPLE-1)) begin
/* verilator lint_on WIDTH */
                        oscnt       <= 0;
                        osen        <= 1'b1;
                    end
                end
            end
        end

    end
endgenerate

endmodule

