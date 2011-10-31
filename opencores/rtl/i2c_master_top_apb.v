
module i2c_master_top_apb #(
    parameter ADDR = 32
) (
    // System
    input   wire                    clk,
    input   wire                    rst,

    // Interrupt
    output  wire                    int_out,
    
    // APB
    input   wire    [ADDR-1:0]      apb_addr,
    input   wire                    apb_sel,
    input   wire                    apb_enable,
    input   wire                    apb_write,
    input   wire    [31:0]          apb_wdata,
    input   wire    [3:0]           apb_strb,
    output  wire                    apb_ready,
    output  wire    [31:0]          apb_rdata,

    // I2C
    input   wire                    scl_in,
    output  wire                    scl_out,
    output  wire                    scl_oe,
    input   wire                    sda_in,
    output  wire                    sda_out,
    output  wire                    sda_oe
);

assign apb_rdata[31:8] = 24'd0;

wire [2:0]  wb_adr_i;
wire [7:0]  wb_dat_i;
wire [7:0]  wb_dat_o;
wire        wb_we_i;
wire        wb_stb_i;
wire        wb_cyc_i;
wire        wb_ack_o;

dlsc_apb_to_wb #(
    .REGISTER       ( 0 ),
    .ADDR           ( 3 ),
    .DATA           ( 8 )
) dlsc_apb_to_wb_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .apb_addr       ( apb_addr[4:2] ),
    .apb_sel        ( apb_sel ),
    .apb_enable     ( apb_enable ),
    .apb_write      ( apb_write ),
    .apb_wdata      ( apb_wdata[7:0] ),
    .apb_strb       ( apb_strb[0] ),
    .apb_ready      ( apb_ready ),
    .apb_rdata      ( apb_rdata[7:0] ),
    .apb_slverr     (  ),
    .wb_cyc_o       ( wb_cyc_i ),
    .wb_stb_o       ( wb_stb_i ),
    .wb_we_o        ( wb_we_i ),
    .wb_adr_o       ( wb_adr_i ),
    .wb_dat_o       ( wb_dat_i ),
    .wb_sel_o       (  ),
    .wb_ack_i       ( wb_ack_o ),
    .wb_err_i       ( 1'b0 ),
    .wb_dat_i       ( wb_dat_o )
);

wire        scl_oe_n;
assign      scl_oe      = !scl_oe_n;

wire        sda_oe_n;
assign      sda_oe      = !sda_oe_n;

i2c_master_top #(
    .ARST_LVL       ( 1'b0 )
) i2c_master_top_inst (
    .wb_clk_i       ( clk ),
    .wb_rst_i       ( rst ),
    .arst_i         ( 1'b1 ),
    .wb_adr_i       ( wb_adr_i ),
    .wb_dat_i       ( wb_dat_i ),
    .wb_dat_o       ( wb_dat_o ),
    .wb_we_i        ( wb_we_i ),
    .wb_stb_i       ( wb_stb_i ),
    .wb_cyc_i       ( wb_cyc_i ),
    .wb_ack_o       ( wb_ack_o ),
    .wb_inta_o      ( int_out ),
    .scl_pad_i      ( scl_in ),
    .scl_pad_o      ( scl_out ),
    .scl_padoen_o   ( scl_oe_n ),
    .sda_pad_i      ( sda_in ),
    .sda_pad_o      ( sda_out ),
    .sda_padoen_o   ( sda_oe_n )
);

endmodule

