
module dlsc_demosaic_vng6_test #(
    parameter DATA = 8
) (
    input   wire                clk,
    input   wire                clk_en,
    input   wire                rst,

    input   wire    [3:0]       st,

    input   wire                px_push,
    input   wire                px_masked,
    input   wire                px_last,
    input   wire                px_row_red,
    input   wire    [DATA-1:0]  px_in,

    output  wire    [DATA  :0]  axes_red_diag,
    output  wire    [DATA  :0]  axes_add,

    output  wire                axes_h_push,
    output  wire                axes_v_push,
    output  wire    [DATA-1:0]  axes_hv,
    output  wire                axes_red_push,
    output  wire    [DATA  :0]  axes_red,
    output  wire                axes_green_push,
    output  wire    [DATA  :0]  axes_green,
    output  wire                axes_blue_push,
    output  wire    [DATA  :0]  axes_blue,

    output  wire                diag_ne_push,
    output  wire    [DATA-1:0]  diag_ne,
    output  wire                diag_se_push,
    output  wire    [DATA-1:0]  diag_se,
    output  wire                diag_red_push,
    output  wire    [DATA  :0]  diag_red,
    output  wire                diag_green_push,
    output  wire    [DATA  :0]  diag_green,

    output  wire                grad_push,
    output  wire    [DATA+2:0]  grad_axes,
    output  wire    [DATA+2:0]  grad_diag,
    output  wire    [DATA+3:0]  thresh,
    
    output  wire    [DATA+3:0]  sum_red,
    output  wire    [DATA+3:0]  sum_green,
    output  wire    [DATA+3:0]  sum_blue,
    output  wire    [3:0]       sum_cnt,
    
    output  wire    [31:0]      diff_norm,

    output  wire    [DATA-1:0]  out_red,
    output  wire    [DATA-1:0]  out_green,
    output  wire    [DATA-1:0]  out_blue,
    output  wire                out_valid
);

dlsc_demosaic_vng6_axes #(
    .DATA           ( DATA )
) dlsc_demosaic_vng6_axes_inst (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .st             ( st ),
    .px_push        ( px_push ),
    .px_in          ( px_in ),
    .axes_red_diag  ( axes_red_diag ),
    .axes_add       ( axes_add ),
    .axes_h_push    ( axes_h_push ),
    .axes_v_push    ( axes_v_push ),
    .axes_hv        ( axes_hv ),
    .axes_red_push  ( axes_red_push ),
    .axes_red       ( axes_red ),
    .axes_green_push( axes_green_push ),
    .axes_green     ( axes_green ),
    .axes_blue_push ( axes_blue_push ),
    .axes_blue      ( axes_blue )
);


dlsc_demosaic_vng6_diag #(
    .DATA           ( DATA )
) dlsc_demosaic_vng6_diag_inst (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .st             ( st ),
    .px_push        ( px_push ),
    .px_in          ( px_in ),
    .axes_red_diag  ( axes_red_diag ),
    .axes_add       ( axes_add ),
    .diag_ne_push   ( diag_ne_push ),
    .diag_ne        ( diag_ne ),
    .diag_se_push   ( diag_se_push ),
    .diag_se        ( diag_se ),
    .diag_red_push  ( diag_red_push ),
    .diag_red       ( diag_red ),
    .diag_green_push( diag_green_push ),
    .diag_green     ( diag_green )
);


dlsc_demosaic_vng6_grad #(
    .DATA           ( DATA )
) dlsc_demosaic_vng6_grad_inst (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .st             ( st ),
    .axes_h_push    ( axes_h_push ),
    .axes_v_push    ( axes_v_push ),
    .axes_hv        ( axes_hv ),
    .diag_ne_push   ( diag_ne_push ),
    .diag_ne        ( diag_ne ),
    .diag_se_push   ( diag_se_push ),
    .diag_se        ( diag_se ),
    .grad_push      ( grad_push ),
    .grad_axes      ( grad_axes ),
    .grad_diag      ( grad_diag ),
    .thresh         ( thresh )
);


dlsc_demosaic_vng6_sum #(
    .DATA           ( DATA )
) dlsc_demosaic_vng6_sum_inst (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .st             ( st ),
    .axes_red_push  ( axes_red_push ),
    .axes_red       ( axes_red ),
    .axes_green_push( axes_green_push ),
    .axes_green     ( axes_green ),
    .axes_blue_push ( axes_blue_push ),
    .axes_blue      ( axes_blue ),
    .diag_red_push  ( diag_red_push ),
    .diag_red       ( diag_red ),
    .diag_green_push( diag_green_push ),
    .diag_green     ( diag_green ),
    .grad_push      ( grad_push ),
    .grad_axes      ( grad_axes ),
    .grad_diag      ( grad_diag ),
    .thresh         ( thresh ),
    .sum_red        ( sum_red ),
    .sum_green      ( sum_green ),
    .sum_blue       ( sum_blue ),
    .sum_cnt        ( sum_cnt )
);

wire    [DATA  :0]  diff_norm_pre;

dlsc_demosaic_vng6_diff #(
    .DATA           ( DATA )
) dlsc_demosaic_vng6_diff_inst (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .st             ( st ),
    .sum_red        ( sum_red ),
    .sum_green      ( sum_green ),
    .sum_blue       ( sum_blue ),
    .sum_cnt        ( sum_cnt ),
    .diff_norm      ( diff_norm_pre )
);

assign diff_norm = { {(31-DATA){diff_norm_pre[DATA]}} , diff_norm_pre };

dlsc_demosaic_vng6_out #(
    .DATA           ( DATA )
) dlsc_demosaic_vng6_out_inst (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .rst            ( rst ),
    .st             ( st ),
    .px_push        ( px_push ),
    .px_masked      ( px_masked ),
    .px_last        ( px_last ),
    .px_row_red     ( px_row_red ),
    .px_in          ( px_in ),
    .diff_norm      ( diff_norm_pre ),
    .out_red        ( out_red ),
    .out_green      ( out_green ),
    .out_blue       ( out_blue ),
    .out_valid      ( out_valid )
);


endmodule


