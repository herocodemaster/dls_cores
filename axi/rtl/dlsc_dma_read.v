
module dlsc_dma_read #(
    parameter DATA      = 32,
    parameter ADDR      = 32,
    parameter LEN       = 4,
    parameter LSB       = 2,
    parameter BUFA      = 9,    // size of buffer is 2**BUFA words
    parameter MOT       = 16,
    parameter TRIG      = 8     // 1-16
) (
    // System
    input   wire                    clk,
    input   wire                    rst,

    // Control/status
    input   wire                    rd_halt,
    output  wire    [1:0]           rd_error,
    output  wire                    rd_busy,
    output  wire                    rd_cmd_done,

    // Triggering
    input   wire    [TRIG-1:0]      rd_trig_in,
    output  wire    [TRIG-1:0]      rd_trig_ack,
    output  wire    [TRIG-1:0]      rd_trig_out,
    
    // Command input
    output  wire                    rd_cmd_almost_empty,
    input   wire                    rd_cmd_push,
    input   wire    [31:0]          rd_cmd_data,

    // FIFO interface
    output  wire                    fifo_wr_push,
    output  wire    [DATA-1:0]      fifo_wr_data,
    input   wire                    fifo_rd_pop,

    // AXI read command
    input   wire                    axi_ar_ready,
    output  wire                    axi_ar_valid,
    output  wire    [ADDR-1:0]      axi_ar_addr,
    output  wire    [LEN-1:0]       axi_ar_len,

    // AXI read data
    output  wire                    axi_r_ready,
    input   wire                    axi_r_valid,
    input   wire                    axi_r_last,
    input   wire    [DATA-1:0]      axi_r_data,
    input   wire    [1:0]           axi_r_resp
);


// Command

wire            cs_pop;
wire [LEN:0]    cs_len;
wire            cs_okay;

dlsc_dma_rwcontrol #(
    .DATA               ( DATA ),
    .ADDR               ( ADDR ),
    .LEN                ( LEN ),
    .LSB                ( LSB ),
    .BUFA               ( BUFA ),
    .MOT                ( MOT )
) dlsc_dma_rwcontrol_inst (
    .clk                ( clk ),
    .rst                ( rst ),
    .halt               ( rd_halt ),
    .error              ( rd_error ),
    .busy               ( rd_busy ),
    .cmd_done           ( rd_cmd_done ),
    .trig_in            ( rd_trig_in ),
    .trig_ack           ( rd_trig_ack ),
    .trig_out           ( rd_trig_out ),
    .cmd_almost_empty   ( rd_cmd_almost_empty ),
    .cmd_push           ( rd_cmd_push ),
    .cmd_data           ( rd_cmd_data ),
    .cs_pop             ( cs_pop ),
    .cs_len             ( cs_len ),
    .cs_okay            ( cs_okay ),
    .axi_c_ready        ( axi_ar_ready ),
    .axi_c_valid        ( axi_ar_valid ),
    .axi_c_addr         ( axi_ar_addr ),
    .axi_c_len          ( axi_ar_len ),
    .axi_r_ready        ( axi_r_ready ),
    .axi_r_valid        ( axi_r_valid ),
    .axi_r_last         ( axi_r_last ),
    .axi_r_resp         ( axi_r_resp )
);


// Track FIFO space

reg  [BUFA:0]   fifo_free;
wire [BUFA:0]   fifo_sub        = fifo_free - { {(BUFA-LEN){1'b0}}, cs_len };
assign          cs_okay         = !fifo_sub[BUFA];

reg             fifo_rd_pop_r;

always @(posedge clk) begin
    if(rst) begin
        fifo_free       <= (2**BUFA);
        fifo_rd_pop_r   <= 1'b0;
    end else begin
        fifo_rd_pop_r   <= fifo_rd_pop;
        if(cs_pop) begin
            fifo_free       <= fifo_sub  + { {BUFA{1'b0}}, fifo_rd_pop_r };
        end else begin
            fifo_free       <= fifo_free + { {BUFA{1'b0}}, fifo_rd_pop_r };
        end
    end
end


// Collect response

wire [1:0]      next_error      = (axi_r_resp == 2'b00) ? rd_error : axi_r_resp;

assign          fifo_wr_push    = axi_r_ready && axi_r_valid && (next_error == 2'b00);
assign          fifo_wr_data    = axi_r_data;


endmodule

