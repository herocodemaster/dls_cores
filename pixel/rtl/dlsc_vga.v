
module dlsc_vga #(
    parameter APB_ADDR          = 32,
    parameter AXI_ADDR          = 32,   // <= 32
    parameter AXI_LEN           = 4,
    parameter AXI_MOT           = 16,
    parameter BUFFER            = 1024, // bytes to buffer
    parameter MAX_H             = 4096, // maximum image width supported (including blanking)
    parameter MAX_V             = 4096, // maximum image height supported (including blanking)
    
    // modeline defaults
    // (640x480 @ 60 Hz; requires 24 MHz px_clk)
    parameter HDISP             = 640,
    parameter HSYNCSTART        = 672,
    parameter HSYNCEND          = 760,
    parameter HTOTAL            = 792,
    parameter VDISP             = 480,
    parameter VSYNCSTART        = 490,
    parameter VSYNCEND          = 495,
    parameter VTOTAL            = 505,

    // pixel defaults
    parameter BYTES_PER_PIXEL   = 3,
    parameter RED_POS           = 2,
    parameter GREEN_POS         = 1,
    parameter BLUE_POS          = 0,
    parameter ALPHA_POS         = 3,

    // buffer defaults
    parameter BYTES_PER_ROW     = HDISP*BYTES_PER_PIXEL,
    parameter ROW_STEP          = BYTES_PER_ROW,
    
    // prevent override of defaults
    parameter FIXED_MODELINE    = 0,
    parameter FIXED_PIXEL       = 0
) (
    // ** Bus Domain **

    // System
    input   wire                    clk,
    input   wire                    rst,

    // APB register bus
    input   wire    [APB_ADDR-1:0]  apb_addr,
    input   wire                    apb_sel,
    input   wire                    apb_enable,
    input   wire                    apb_write,
    input   wire    [31:0]          apb_wdata,
    input   wire    [3:0]           apb_strb,
    output  wire                    apb_ready,
    output  wire    [31:0]          apb_rdata,

    // Interrupt
    output  wire                    int_out,

    // AXI read command
    input   wire                    axi_ar_ready,
    output  wire                    axi_ar_valid,
    output  wire    [AXI_ADDR-1:0]  axi_ar_addr,
    output  wire    [AXI_LEN-1:0]   axi_ar_len,

    // AXI read response
    output  wire                    axi_r_ready,
    input   wire                    axi_r_valid,
    input   wire                    axi_r_last,
    input   wire    [31:0]          axi_r_data,
    input   wire    [1:0]           axi_r_resp,
    
    // ** Pixel Domain **

    // System
    input   wire                    px_clk,
    input   wire                    px_rst,

    // Video output
    output  wire                    px_en,          // timing generator is out of reset and enabled
    output  wire                    px_vsync,
    output  wire                    px_hsync,
    output  wire                    px_frame_valid,
    output  wire                    px_line_valid,
    output  wire                    px_valid,
    output  wire    [7:0]           px_r,
    output  wire    [7:0]           px_g,
    output  wire    [7:0]           px_b,
    output  wire    [7:0]           px_a
);

`include "dlsc_clog2.vh"

localparam XBITS        = `dlsc_clog2(MAX_H);
localparam YBITS        = `dlsc_clog2(MAX_V);
localparam BLEN         = `dlsc_clog2(MAX_H*4);
localparam FIFO_ADDR    = `dlsc_clog2(BUFFER/4);

// registers/control

wire                    rst_bus;
wire                    axi_halt;
wire                    axi_busy;
wire                    axi_error;
wire                    axi_cmd_ready;
wire                    axi_cmd_valid;
wire    [AXI_ADDR-1:0]  axi_cmd_addr;
wire    [BLEN-1:0]      axi_cmd_bytes;
wire    [FIFO_ADDR-1:0] fifo_free;
wire    [XBITS-1:0]     hdisp;
wire    [XBITS-1:0]     hsyncstart;
wire    [XBITS-1:0]     hsyncend;
wire    [XBITS-1:0]     htotal;
wire    [YBITS-1:0]     vdisp;
wire    [YBITS-1:0]     vsyncstart;
wire    [YBITS-1:0]     vsyncend;
wire    [YBITS-1:0]     vtotal;
wire    [1:0]           pos_r;
wire    [1:0]           pos_g;
wire    [1:0]           pos_b;
wire    [1:0]           pos_a;
wire                    px_rst_bus;
wire                    px_rst_drv;
wire                    px_frame_start;
wire                    px_frame_done;
wire                    px_underrun;
wire                    px_cmd_ready;
wire                    px_cmd_valid;
wire    [1:0]           px_cmd_offset;
wire    [1:0]           px_cmd_bpw;
wire    [XBITS-1:0]     px_cmd_words;

dlsc_vga_registers #(
    .APB_ADDR           ( APB_ADDR ),
    .AXI_ADDR           ( AXI_ADDR ),
    .BLEN               ( BLEN ),
    .XBITS              ( XBITS ),
    .YBITS              ( YBITS ),
    .HDISP              ( HDISP ),
    .HSYNCSTART         ( HSYNCSTART ),
    .HSYNCEND           ( HSYNCEND ),
    .HTOTAL             ( HTOTAL ),
    .VDISP              ( VDISP ),
    .VSYNCSTART         ( VSYNCSTART ),
    .VSYNCEND           ( VSYNCEND ),
    .VTOTAL             ( VTOTAL ),
    .BYTES_PER_PIXEL    ( BYTES_PER_PIXEL ),
    .RED_POS            ( RED_POS ),
    .GREEN_POS          ( GREEN_POS ),
    .BLUE_POS           ( BLUE_POS ),
    .ALPHA_POS          ( ALPHA_POS ),
    .BYTES_PER_ROW      ( BYTES_PER_ROW ),
    .ROW_STEP           ( ROW_STEP ),
    .FIXED_MODELINE     ( FIXED_MODELINE ),
    .FIXED_PIXEL        ( FIXED_PIXEL )
) dlsc_vga_registers_inst (
    .clk                ( clk ),
    .rst_in             ( rst ),
    .rst_bus            ( rst_bus ),
    .rst_drv            (  ),
    .apb_addr           ( apb_addr ),
    .apb_sel            ( apb_sel ),
    .apb_enable         ( apb_enable ),
    .apb_write          ( apb_write ),
    .apb_wdata          ( apb_wdata ),
    .apb_strb           ( apb_strb ),
    .apb_ready          ( apb_ready ),
    .apb_rdata          ( apb_rdata ),
    .int_out            ( int_out ),
    .axi_halt           ( axi_halt ),
    .axi_busy           ( axi_busy ),
    .axi_error          ( axi_error ),
    .axi_cmd_ready      ( axi_cmd_ready ),
    .axi_cmd_valid      ( axi_cmd_valid ),
    .axi_cmd_addr       ( axi_cmd_addr ),
    .axi_cmd_bytes      ( axi_cmd_bytes ),
    .hdisp              ( hdisp ),
    .hsyncstart         ( hsyncstart ),
    .hsyncend           ( hsyncend ),
    .htotal             ( htotal ),
    .vdisp              ( vdisp ),
    .vsyncstart         ( vsyncstart ),
    .vsyncend           ( vsyncend ),
    .vtotal             ( vtotal ),
    .pos_r              ( pos_r ),
    .pos_g              ( pos_g ),
    .pos_b              ( pos_b ),
    .pos_a              ( pos_a ),
    .px_clk             ( px_clk ),
    .px_rst_in          ( px_rst ),
    .px_rst_bus         ( px_rst_bus ),
    .px_rst_drv         ( px_rst_drv ),
    .px_frame_start     ( px_frame_start ),
    .px_frame_done      ( px_frame_done ),
    .px_underrun        ( px_underrun ),
    .px_cmd_ready       ( px_cmd_ready ),
    .px_cmd_valid       ( px_cmd_valid ),
    .px_cmd_offset      ( px_cmd_offset ),
    .px_cmd_bpw         ( px_cmd_bpw ),
    .px_cmd_words       ( px_cmd_words )
);

// AXI reader

wire    [FIFO_ADDR:0]   fifo_wr_free;
wire                    fifo_wr_push;
wire    [31:0]          fifo_wr_data;

dlsc_axi_reader #(
    .ADDR               ( AXI_ADDR ),
    .LEN                ( AXI_LEN ),
    .BLEN               ( BLEN ),
    .MOT                ( AXI_MOT ),
    .FIFO_ADDR          ( FIFO_ADDR ),
    .STROBE_EN          ( 0 ),
) dlsc_axi_reader_inst (
    .clk                ( clk ),
    .rst                ( rst_bus ),
    .axi_halt           ( axi_halt ),
    .axi_busy           ( axi_busy ),
    .axi_error          ( axi_error ),
    .cmd_done           (  ),
    .cmd_ready          ( axi_cmd_ready ),
    .cmd_valid          ( axi_cmd_valid ),
    .cmd_addr           ( axi_cmd_addr ),
    .cmd_bytes          ( axi_cmd_bytes ),
    .axi_ar_ready       ( axi_ar_ready ),
    .axi_ar_valid       ( axi_ar_valid ),
    .axi_ar_addr        ( axi_ar_addr ),
    .axi_ar_len         ( axi_ar_len ),
    .axi_r_ready        ( axi_r_ready ),
    .axi_r_valid        ( axi_r_valid ),
    .axi_r_last         ( axi_r_last ),
    .axi_r_data         ( axi_r_data ),
    .axi_r_resp         ( axi_r_resp ),
    .out_free           ( fifo_wr_free ),
    .out_ready          ( 1'b1 ),
    .out_valid          ( fifo_wr_push ),
    .out_last           (  ),
    .out_data           ( fifo_wr_data ),
    .out_strb           (  )
);

// buffer FIFO

wire                    fifo_rd_ready;
wire                    fifo_rd_valid;

wire                    fifo_rd_pop;
wire                    fifo_rd_empty;
wire    [31:0]          fifo_rd_data;

assign                  fifo_rd_valid   = !fifo_rd_empty;
assign                  fifo_rd_pop     = (fifo_rd_ready && fifo_rd_valid);

dlsc_fifo_async #(
    .DATA               ( 32 ),
    .ADDR               ( FIFO_ADDR )
) dlsc_fifo_async_inst (
    .wr_clk             ( clk ),
    .wr_rst             ( rst_bus ),
    .wr_push            ( fifo_wr_push ),
    .wr_data            ( fifo_wr_data ),
    .wr_full            (  ),
    .wr_almost_full     (  ),
    .wr_free            ( fifo_wr_free ),
    .rd_clk             ( px_clk ),
    .rd_rst             ( px_rst_bus ),
    .rd_pop             ( fifo_rd_pop ),
    .rd_data            ( fifo_rd_data ),
    .rd_empty           ( fifo_rd_empty ),
    .rd_almost_empty    (  ),
    .rd_count           (  )
);

// unpacker

wire                    up_ready;
wire                    up_valid;
wire    [31:0]          up_data;

dlsc_data_unpacker #(
    .WLEN               ( XBITS ),
    .WORDS_ZERO         ( 1 )       // cmd_words starts from 0 (0 indicates 1 word)
) dlsc_data_unpacker_inst (
    .clk                ( px_clk ),
    .rst                ( px_rst_bus ),
    .cmd_done           (  ),
    .cmd_ready          ( px_cmd_ready ),
    .cmd_valid          ( px_cmd_valid ),
    .cmd_offset         ( px_cmd_offset ),
    .cmd_bpw            ( px_cmd_bpw ),
    .cmd_words          ( px_cmd_words ),
    .in_ready           ( fifo_rd_ready ),
    .in_valid           ( fifo_rd_valid ),
    .in_data            ( fifo_rd_data ),
    .out_ready          ( up_ready ),
    .out_valid          ( up_valid ),
    .out_last           (  ),
    .out_data           ( up_data )
);

// output driver

dlsc_vga_output #(
    .XBITS              ( XBITS ),
    .YBITS              ( YBITS )
) dlsc_vga_output_inst (
    .clk                ( px_clk ),
    .rst                ( px_rst_drv ),
    .frame_start        ( px_frame_start ),
    .frame_done         ( px_frame_done ),
    .underrun           ( px_underrun ),
    .hdisp              ( hdisp ),
    .hsyncstart         ( hsyncstart ),
    .hsyncend           ( hsyncend ),
    .htotal             ( htotal ),
    .vdisp              ( vdisp ),
    .vsyncstart         ( vsyncstart ),
    .vsyncend           ( vsyncend ),
    .vtotal             ( vtotal ),
    .pos_r              ( pos_r ),
    .pos_g              ( pos_g ),
    .pos_b              ( pos_b ),
    .pos_a              ( pos_a ),
    .in_ready           ( up_ready ),
    .in_valid           ( up_valid ),
    .in_data            ( up_data ),
    .px_en              ( px_en ),
    .px_vsync           ( px_vsync ),
    .px_hsync           ( px_hsync ),
    .px_frame_valid     ( px_frame_valid ),
    .px_line_valid      ( px_line_valid ),
    .px_valid           ( px_valid ),
    .px_r               ( px_r ),
    .px_g               ( px_g ),
    .px_b               ( px_b ),
    .px_a               ( px_a )
);

endmodule

