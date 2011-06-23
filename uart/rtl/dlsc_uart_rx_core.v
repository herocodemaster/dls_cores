
module dlsc_uart_rx_core #(
    parameter START         = 1,
    parameter STOP          = 1,
    parameter DATA          = 8,
    parameter PARITY        = 0,    // 0 = NONE, 1 = ODD, 2 = EVEN
    parameter OVERSAMPLE    = 16
) (
    // system
    input   wire                clk,
    input   wire                clk_en,         // should enable at BAUD*OVERSAMPLE
    input   wire                rst,

    // uart pins
    input   wire                rx,

    // received data
    output  reg                 valid,          // qualifier; asserts for just 1 cycle
    output  reg     [DATA-1:0]  data,           // received data
    output  reg                 frame_error,    // start/stop bits incorrect
    output  reg                 parity_error    // parity check failed
);

`include "dlsc_clog2.vh"

localparam CNTBITS  = `dlsc_clog2(DATA);
localparam OSBITS   = `dlsc_clog2(OVERSAMPLE);


// ** input filter

wire rxf;

dlsc_glitchfilter #(
    .DEPTH      ( OVERSAMPLE/4 ),
    .RESET      ( 1'b1 )
) dlsc_glitchfilter_inst_rx (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .rst        ( rst ),
    .in         ( rx ),
    .out        ( rxf )
);

reg rxf_prev;

always @(posedge clk) begin
    if(rst) begin
        rxf_prev    <= 1'b1;
    end else if(clk_en) begin
        rxf_prev    <= rxf;
    end
end


// ** control

localparam  ST_START    = 0,
            ST_DATA     = 1,
            ST_PARITY   = 2,
            ST_STOP     = 3;

reg                 st_idle;
reg [1:0]           st;
reg [CNTBITS-1:0]   cnt;
reg                 parity;

reg                 sample_en;

/* verilator lint_off WIDTH */

always @(posedge clk) begin
    if(rst || valid) begin
        st              <= ST_START;
        st_idle         <= 1'b1;        // idle flag forces IDLE state
        cnt             <= 0;
        parity          <= (PARITY == 1) ? 1'b1 : 1'b0;
        valid           <= 1'b0;
        data            <= 0;
        frame_error     <= 1'b0;
        parity_error    <= 1'b0;
    end else begin

        if(clk_en && st_idle && rxf_prev && !rxf) begin
            // start detected; leave IDLE
            st_idle         <= 1'b0;
        end

        if(clk_en && sample_en) begin

            cnt             <= cnt + 1;

            if(st == ST_START) begin
                if(rxf != 1'b0) begin
                    frame_error     <= 1'b1;
                end
                if((START==1) || cnt == (START-1)) begin
                    st              <= ST_DATA;
                    cnt             <= 0;
                end
            end

            if(st == ST_DATA) begin
                parity          <= parity ^ rxf;
                data            <= {rxf,data[DATA-1:1]};
                if(cnt == (DATA-1)) begin
                    st              <= (PARITY == 0) ? ST_STOP : ST_PARITY;
                    cnt             <= 0;
                end
            end

            if(st == ST_PARITY && PARITY != 0) begin
                parity_error    <= (rxf != parity);
                st              <= ST_STOP;
                cnt             <= 0;
            end

            if(st == ST_STOP) begin
                if(rxf != 1'b1) begin
                    frame_error     <= 1'b1;
                end
                if((STOP==1) || cnt == (STOP-1)) begin
                    // once valid is asserted, control will reset back to IDLE
                    valid           <= 1'b1;
                end
            end

        end

    end
end

/* verilator lint_on WIDTH */


// ** sampler

reg [OSBITS-1:0] oscnt;

/* verilator lint_off WIDTH */

always @(posedge clk) begin
    if(rst || valid) begin
        oscnt       <= 0;
        sample_en   <= 1'b0;
    end else if(clk_en && !st_idle) begin
        oscnt       <= oscnt + 1;
        if(oscnt == ( OVERSAMPLE   -1)) oscnt <= 0;
        sample_en   <= 1'b0;
        if(oscnt == ((OVERSAMPLE/2)-2)) sample_en <= 1'b1;
    end
end

/* verilator lint_on WIDTH */

endmodule

