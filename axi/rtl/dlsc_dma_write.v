
module dlsc_dma_write #(
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
    input   wire                    wr_halt,
    output  wire    [1:0]           wr_error,
    output  wire                    wr_busy,
    output  wire                    wr_cmd_done,

    // Triggering
    input   wire    [TRIG-1:0]      wr_trig_in,
    output  wire    [TRIG-1:0]      wr_trig_ack,
    output  wire    [TRIG-1:0]      wr_trig_out,
    
    // Command input
    output  wire                    wr_cmd_almost_empty,
    input   wire                    wr_cmd_push,
    input   wire    [31:0]          wr_cmd_data,

    // FIFO interface
    output  wire                    fifo_rd_pop,
    input   wire    [DATA-1:0]      fifo_rd_data,
    input   wire    [BUFA:0]        fifo_rd_count,
    input   wire                    fifo_rd_empty,
    
    // AXI write command
    input   wire                    axi_aw_ready,
    output  wire                    axi_aw_valid,
    output  wire    [ADDR-1:0]      axi_aw_addr,
    output  wire    [LEN-1:0]       axi_aw_len,

    // AXI write data
    input   wire                    axi_w_ready,
    output  reg                     axi_w_valid,
    output  reg                     axi_w_last,
    output  reg     [(DATA/8)-1:0]  axi_w_strb,
    output  reg     [DATA-1:0]      axi_w_data,

    // AXI write response
    output  wire                    axi_b_ready,
    input   wire                    axi_b_valid,
    input   wire    [1:0]           axi_b_resp
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
    .MOT                ( MOT ),
    .TRIG               ( TRIG )
) dlsc_dma_rwcontrol_inst (
    .clk                ( clk ),
    .rst                ( rst ),
    .halt               ( wr_halt ),
    .error              ( wr_error ),
    .busy               ( wr_busy ),
    .cmd_done           ( wr_cmd_done ),
    .trig_in            ( wr_trig_in ),
    .trig_ack           ( wr_trig_ack ),
    .trig_out           ( wr_trig_out ),
    .cmd_almost_empty   ( wr_cmd_almost_empty ),
    .cmd_push           ( wr_cmd_push ),
    .cmd_data           ( wr_cmd_data ),
    .cs_pop             ( cs_pop ),
    .cs_len             ( cs_len ),
    .cs_okay            ( cs_okay ),
    .axi_c_ready        ( axi_aw_ready ),
    .axi_c_valid        ( axi_aw_valid ),
    .axi_c_addr         ( axi_aw_addr ),
    .axi_c_len          ( axi_aw_len ),
    .axi_r_ready        ( axi_b_ready ),
    .axi_r_valid        ( axi_b_valid ),
    .axi_r_last         ( 1'b1 ),
    .axi_r_resp         ( axi_b_resp )
);


// Check FIFO space

assign          cs_okay         = (!axi_w_valid || axi_w_ready) && axi_w_last && !fifo_rd_empty && (fifo_rd_count >= { {(BUFA-LEN){1'b0}}, cs_len});

assign          fifo_rd_pop     = (!axi_w_valid || axi_w_ready) && (!axi_w_last || cs_pop);


// Issue data

reg  [LEN-1:0]      w_cnt;

always @(posedge clk) begin
    if(fifo_rd_pop) begin
        w_cnt       <= axi_w_last ? 1 : (w_cnt + 1);
    end
end

always @(posedge clk) begin
    if(rst) begin
        axi_w_valid     <= 1'b0;
        axi_w_last      <= 1'b1;
    end else begin
        if(axi_w_ready) begin
            axi_w_valid     <= 1'b0;
        end
        if(fifo_rd_pop) begin
            axi_w_valid     <= 1'b1;
            axi_w_last      <= axi_w_last ? (cs_len == 1) : (w_cnt == axi_aw_len);
        end
    end
end

always @(posedge clk) begin
    if(fifo_rd_pop) begin
        axi_w_strb      <= {(DATA/8){1'b1}};
        axi_w_data      <= fifo_rd_data;
    end
end


endmodule

