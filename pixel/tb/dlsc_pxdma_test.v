
module dlsc_pxdma_test #(
    // ** Clock Domains **
    parameter AXI_ASYNC         = 0,
    parameter IN_ASYNC          = 0,
    parameter OUT_ASYNC         = 0,
    // ** Config **
    parameter READERS           = 1,                    // number of pxdma_readers (1-4)
    parameter IN_BUFFER         = ((2**AXI_LEN)*8),
    parameter OUT_BUFFER        = 1024,
    parameter MAX_H             = 1024,                 // maximum horizontal resolution
    parameter MAX_V             = 1024,                 // maximum vertical resolution
    parameter BYTES_PER_PIXEL   = 3,                    // bytes per pixel; 1-4
    // derived; don't touch
    parameter PX_DATA           = (BYTES_PER_PIXEL*8),
    // ** AXI **
    parameter AXI_ADDR          = 32,                   // size of AXI address field
    parameter AXI_LEN           = 4,                    // size of AXI length field
    parameter AXI_MOT           = 16,                   // maximum outstanding transactions
    // ** CSR **
    parameter CSR_ADDR          = 32
) (

/* verilator coverage_off */
    
    // ** CSR Domain **

    // System
    input   wire                    csr_clk,
    input   wire                    csr_rst,

    // Status
    output  wire    [READERS:0]     csr_enabled,        // asserted when engine is enabled
    
    // CSR command
    input   wire                    csr_cmd_valid,
    input   wire                    csr_cmd_write,
    input   wire    [CSR_ADDR-1:0]  csr_cmd_addr,
    input   wire    [31:0]          csr_cmd_data,

    // CSR response
    output  reg                     csr_rsp_valid,
    output  reg                     csr_rsp_error,
    output  reg     [31:0]          csr_rsp_data,

    // Interrupt
    output  wire    [READERS:0]     csr_int,

    // ** AXI Doamin **

    // System
    input   wire                    axi_clk,
    input   wire                    axi_rst,
    
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
    
    // AXI write command
    input   wire                    axi_aw_ready,
    output  wire                    axi_aw_valid,
    output  wire    [AXI_ADDR-1:0]  axi_aw_addr,
    output  wire    [AXI_LEN-1:0]   axi_aw_len,

    // AXI write data
    input   wire                    axi_w_ready,
    output  wire                    axi_w_valid,
    output  wire                    axi_w_last,
    output  wire    [31:0]          axi_w_data,
    output  wire    [3:0]           axi_w_strb,

    // AXI write response
    output  wire                    axi_b_ready,
    input   wire                    axi_b_valid,
    input   wire    [1:0]           axi_b_resp,

    // ** Pixel Domains **

    // Pixel input
    input   wire                    in_clk,
    input   wire                    in_rst,
    output  wire                    in_ready,
    input   wire                    in_valid,
    input   wire    [PX_DATA-1:0]   in_data,

    // Pixel outputs
    // 0
    input   wire                    out0_clk,
    input   wire                    out0_rst,
    input   wire                    out0_ready,
    output  wire                    out0_valid,
    output  wire    [PX_DATA-1:0]   out0_data,
    // 1
    input   wire                    out1_clk,
    input   wire                    out1_rst,
    input   wire                    out1_ready,
    output  wire                    out1_valid,
    output  wire    [PX_DATA-1:0]   out1_data,
    // 2
    input   wire                    out2_clk,
    input   wire                    out2_rst,
    input   wire                    out2_ready,
    output  wire                    out2_valid,
    output  wire    [PX_DATA-1:0]   out2_data,
    // 3
    input   wire                    out3_clk,
    input   wire                    out3_rst,
    input   wire                    out3_ready,
    output  wire                    out3_valid,
    output  wire    [PX_DATA-1:0]   out3_data
);

localparam CSR_DOMAIN   = 0;
localparam AXI_DOMAIN   = AXI_ASYNC ? 1 : 0;
localparam IN_DOMAIN    = IN_ASYNC ? 2 : 0;
localparam OUT_DOMAIN   = OUT_ASYNC ? 3 : 0;

// ** CSR decode/mux **

reg     [READERS:0]     csr_cmd_valid_i;
wire    [READERS:0]     csr_rsp_valid_i;
wire    [READERS:0]     csr_rsp_error_i;
wire    [31:0]          csr_rsp_data_i [READERS:0];

integer i;

/* verilator lint_off WIDTH */
always @* begin
    csr_cmd_valid_i = 0;
    csr_rsp_valid   = 0;
    csr_rsp_error   = 0;
    csr_rsp_data    = 0;

    for(i=0;i<=READERS;i=i+1) begin
        csr_cmd_valid_i[i]  = csr_cmd_valid && (csr_cmd_addr[CSR_ADDR-1:12] == i);
        csr_rsp_valid       = csr_rsp_valid | csr_rsp_valid_i[i];
        csr_rsp_error       = csr_rsp_error | csr_rsp_error_i[i];
        csr_rsp_data        = csr_rsp_data  | csr_rsp_data_i[i];
    end
end
/* verilator lint_on WIDTH */


// ** Writer **

wire    [READERS-1:0]   csr_row_written;
wire    [READERS-1:0]   csr_row_read;

dlsc_pxdma_writer #(
    .CSR_DOMAIN ( CSR_DOMAIN ),
    .AXI_DOMAIN ( AXI_DOMAIN ),
    .PX_DOMAIN ( IN_DOMAIN ),
    .READERS ( READERS ),
    .BUFFER ( IN_BUFFER ),
    .MAX_H ( MAX_H ),
    .MAX_V ( MAX_V ),
    .BYTES_PER_PIXEL ( BYTES_PER_PIXEL ),
    .AXI_ADDR ( AXI_ADDR ),
    .AXI_LEN ( AXI_LEN ),
    .AXI_MOT ( AXI_MOT ),
    .CSR_ADDR ( CSR_ADDR )
) dlsc_pxdma_writer (
    // ** CSR **
    .csr_clk ( csr_clk ),
    .csr_rst ( csr_rst ),
    .csr_rst_out (  ),
    .csr_enabled ( csr_enabled[0] ),
    .csr_row_written ( csr_row_written ),
    .csr_row_read ( csr_row_read ),
    .csr_cmd_valid ( csr_cmd_valid_i[0] ),
    .csr_cmd_write ( csr_cmd_write ),
    .csr_cmd_addr ( csr_cmd_addr ),
    .csr_cmd_data ( csr_cmd_data ),
    .csr_rsp_valid ( csr_rsp_valid_i[0] ),
    .csr_rsp_error ( csr_rsp_error_i[0] ),
    .csr_rsp_data ( csr_rsp_data_i[0] ),
    .csr_int ( csr_int[0] ),
    // ** AXI **
    .axi_clk ( axi_clk ),
    .axi_rst ( axi_rst ),
    .axi_rst_out (  ),
    .axi_aw_ready ( axi_aw_ready ),
    .axi_aw_valid ( axi_aw_valid ),
    .axi_aw_addr ( axi_aw_addr ),
    .axi_aw_len ( axi_aw_len ),
    .axi_w_ready ( axi_w_ready ),
    .axi_w_valid ( axi_w_valid ),
    .axi_w_last ( axi_w_last ),
    .axi_w_data ( axi_w_data ),
    .axi_w_strb ( axi_w_strb ),
    .axi_b_ready ( axi_b_ready ),
    .axi_b_valid ( axi_b_valid ),
    .axi_b_resp ( axi_b_resp ),
    // ** Pixel **
    .px_clk ( in_clk ),
    .px_rst ( in_rst ),
    .px_rst_out (  ),
    .px_ready ( in_ready ),
    .px_valid ( in_valid ),
    .px_data ( in_data )
);


// ** Readers **

wire    [READERS-1:0]   out_clk;
wire    [READERS-1:0]   out_rst;
wire    [READERS-1:0]   out_ready;
wire    [READERS-1:0]   out_valid;
wire    [PX_DATA-1:0]   out_data [READERS-1:0];
    
wire [ READERS          -1:0] readers_ar_ready;
wire [ READERS          -1:0] readers_ar_valid;
wire [(READERS*AXI_ADDR)-1:0] readers_ar_addr;
wire [(READERS*AXI_LEN )-1:0] readers_ar_len;
wire [ READERS          -1:0] readers_r_ready;
wire [ READERS          -1:0] readers_r_valid;
wire [ READERS          -1:0] readers_r_last;
wire [(READERS*32      )-1:0] readers_r_data;
wire [(READERS*2       )-1:0] readers_r_resp;

genvar j;
generate
for(j=0;j<READERS;j=j+1) begin:GEN_READERS

    dlsc_pxdma_reader #(
        .CSR_DOMAIN ( CSR_DOMAIN ),
        .AXI_DOMAIN ( AXI_DOMAIN ),
        .PX_DOMAIN ( OUT_DOMAIN ),
        .WRITERS ( 1 ),
        .BUFFER ( OUT_BUFFER ),
        .MAX_H ( MAX_H ),
        .MAX_V ( MAX_V ),
        .BYTES_PER_PIXEL ( BYTES_PER_PIXEL ),
        .AXI_ADDR ( AXI_ADDR ),
        .AXI_LEN ( AXI_LEN ),
        .AXI_MOT ( AXI_MOT ),
        .CSR_ADDR ( CSR_ADDR )
    ) dlsc_pxdma_reader (
        // ** CSR **
        .csr_clk ( csr_clk ),
        .csr_rst ( csr_rst ),
        .csr_rst_out (  ),
        .csr_enabled ( csr_enabled[j+1] ),
        .csr_row_written ( csr_row_written[j] ),
        .csr_row_read ( csr_row_read[j] ),
        .csr_cmd_valid ( csr_cmd_valid_i[j+1] ),
        .csr_cmd_write ( csr_cmd_write ),
        .csr_cmd_addr ( csr_cmd_addr ),
        .csr_cmd_data ( csr_cmd_data ),
        .csr_rsp_valid ( csr_rsp_valid_i[j+1] ),
        .csr_rsp_error ( csr_rsp_error_i[j+1] ),
        .csr_rsp_data ( csr_rsp_data_i[j+1] ),
        .csr_int ( csr_int[j+1] ),
        // ** AXI **
        .axi_clk ( axi_clk ),
        .axi_rst ( axi_rst ),
        .axi_rst_out (  ),
        .axi_ar_ready ( readers_ar_ready[j] ),
        .axi_ar_valid ( readers_ar_valid[j] ),
        .axi_ar_addr ( readers_ar_addr[ j*AXI_ADDR +: AXI_ADDR ] ),
        .axi_ar_len ( readers_ar_len[ j*AXI_LEN +: AXI_LEN ] ),
        .axi_r_ready ( readers_r_ready[j] ),
        .axi_r_valid ( readers_r_valid[j] ),
        .axi_r_last ( readers_r_last[j] ),
        .axi_r_data ( readers_r_data[ j*32 +: 32 ] ),
        .axi_r_resp ( readers_r_resp[ j*2 +: 2 ] ),
        // ** Pixel **
        .px_clk ( out_clk[j] ),
        .px_rst ( out_rst[j] ),
        .px_rst_out (  ),
        .px_ready ( out_ready[j] ),
        .px_valid ( out_valid[j] ),
        .px_data ( out_data[j] )
    );
end

if(READERS>1) begin:GEN_READER1
    assign  out_clk[1]      = out1_clk;
    assign  out_rst[1]      = out1_rst;
    assign  out_ready[1]    = out1_ready;
    assign  out1_valid      = out_valid[1];
    assign  out1_data       = out_data[1];
end else begin:GEN_NO_READER1
    assign  out1_valid      = 0;
    assign  out1_data       = 0;
end

if(READERS>2) begin:GEN_READER2
    assign  out_clk[2]      = out2_clk;
    assign  out_rst[2]      = out2_rst;
    assign  out_ready[2]    = out2_ready;
    assign  out2_valid      = out_valid[2];
    assign  out2_data       = out_data[2];
end else begin:GEN_NO_READER2
    assign  out2_valid      = 0;
    assign  out2_data       = 0;
end

if(READERS>3) begin:GEN_READER3
    assign  out_clk[3]      = out3_clk;
    assign  out_rst[3]      = out3_rst;
    assign  out_ready[3]    = out3_ready;
    assign  out3_valid      = out_valid[3];
    assign  out3_data       = out_data[3];
end else begin:GEN_NO_READER3
    assign  out3_valid      = 0;
    assign  out3_data       = 0;
end
endgenerate

assign  out_clk[0]      = out0_clk;
assign  out_rst[0]      = out0_rst;
assign  out_ready[0]    = out0_ready;
assign  out0_valid      = out_valid[0];
assign  out0_data       = out_data[0];


// ** AXI Read Router **

dlsc_axi_router_rd #(
    .ADDR       ( AXI_ADDR ),
    .DATA       ( 32 ),
    .LEN        ( AXI_LEN ),
    .BUFFER     ( 1 ),
    .INPUTS     ( READERS ),
    .OUTPUTS    ( 1 )
) dlsc_axi_router_rd (
    .clk ( axi_clk ),
    .rst ( axi_rst ),
    .in_ar_ready ( readers_ar_ready ),
    .in_ar_valid ( readers_ar_valid ),
    .in_ar_addr ( readers_ar_addr ),
    .in_ar_len ( readers_ar_len ),
    .in_r_ready ( readers_r_ready ),
    .in_r_valid ( readers_r_valid ),
    .in_r_last ( readers_r_last ),
    .in_r_data ( readers_r_data ),
    .in_r_resp ( readers_r_resp ),
    .out_ar_ready ( axi_ar_ready ),
    .out_ar_valid ( axi_ar_valid ),
    .out_ar_addr ( axi_ar_addr ),
    .out_ar_len ( axi_ar_len ),
    .out_r_ready ( axi_r_ready ),
    .out_r_valid ( axi_r_valid ),
    .out_r_last ( axi_r_last ),
    .out_r_data ( axi_r_data ),
    .out_r_resp ( axi_r_resp )
);

/* verilator coverage_on */

endmodule

