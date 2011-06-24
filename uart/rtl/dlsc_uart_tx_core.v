
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

localparam CNTBITS  = `dlsc_clog2(DATA);
localparam OSBITS   = `dlsc_clog2(OVERSAMPLE);


localparam  ST_IDLE     = 0,
            ST_START    = 1,
            ST_DATA     = 2,
            ST_PARITY   = 4,
            ST_STOP     = 3;

reg [2:0]           st;
reg [CNTBITS-1:0]   cnt;
reg                 parity;

reg [DATA-1:0]      data_sr;

wire                clk_en_div;

/* verilator lint_off WIDTH */

always @(posedge clk) begin
    if(rst) begin

        st              <= ST_IDLE;
        cnt             <= 0;
        parity          <= (PARITY == 1) ? 1'b1 : 1'b0;
        data_sr         <= 0;
        tx              <= 1'b1;
        tx_en           <= 1'b0;
        ready           <= 1'b1;

    end else begin

        if(ready && valid) begin
            ready           <= 1'b0;
            data_sr         <= data;
        end

        if(clk_en_div) begin

            cnt             <= cnt + 1;
            tx_en           <= (st != ST_IDLE);
            parity          <= (PARITY == 1) ? 1'b1 : 1'b0;

            if(st == ST_IDLE) begin
                tx              <= 1'b1;
                cnt             <= 0;
                if(!ready) begin
                    st              <= ST_START;
                end
            end

            if(st == ST_START) begin
                tx              <= 1'b0;
                if(cnt == (START-1)) begin
                    st              <= ST_DATA;
                    cnt             <= 0;
                end
            end

            if(st == ST_DATA) begin
                tx              <= data_sr[cnt];
                parity          <= data_sr[cnt] ^ parity;
                if(cnt == (DATA-1)) begin
                    st              <= (PARITY == 0) ? ST_STOP : ST_PARITY;
                    cnt             <= 0;
                    ready           <= 1'b1;    // can accept another word now
                end
            end

            if(st == ST_PARITY && PARITY != 0) begin
                tx              <= parity;
                st              <= ST_STOP;
                cnt             <= 0;
            end

            if(st == ST_STOP) begin
                tx              <= 1'b1;
                if(cnt == (STOP-1)) begin
                    // if we already have another word, immediately send it
                    st              <= ready ? ST_IDLE : ST_START;
                    cnt             <= 0;
                end
            end

        end

    end
end

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
                    if(oscnt == (OVERSAMPLE-1)) begin
                        oscnt       <= 0;
                        osen        <= 1'b1;
                    end
                end
            end
        end

    end
endgenerate

/* verilator lint_on WIDTH */

endmodule

