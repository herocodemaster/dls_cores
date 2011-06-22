
module dlsc_demosaic_vng6_core #(
    parameter DATA = 8
) (
    input   wire                clk,
    input   wire                clk_en,

    input   wire    [3:0]       st,

    input   wire                px_push,
    input   wire    [DATA-1:0]  px_in,
    
    output  wire    [DATA  :0]  diff_norm
);
    
wire    [DATA  :0]  axes_red_diag;
wire    [DATA  :0]  axes_add;

wire                axes_h_push;
wire                axes_v_push;
wire    [DATA-1:0]  axes_hv;
wire                axes_red_push;
wire    [DATA  :0]  axes_red;
wire                axes_green_push;
wire    [DATA  :0]  axes_green;
wire                axes_blue_push;
wire    [DATA  :0]  axes_blue;

wire                diag_ne_push;
wire    [DATA-1:0]  diag_ne;
wire                diag_se_push;
wire    [DATA-1:0]  diag_se;
wire                diag_red_push;
wire    [DATA  :0]  diag_red;
wire                diag_green_push;
wire    [DATA  :0]  diag_green;

wire                grad_push;
wire    [DATA+2:0]  grad_axes;
wire    [DATA+2:0]  grad_diag;
wire    [DATA+3:0]  thresh;
    
wire    [DATA+3:0]  sum_red;
wire    [DATA+3:0]  sum_green;
wire    [DATA+3:0]  sum_blue;
wire    [3:0]       sum_cnt;

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
    .diff_norm      ( diff_norm )
);

endmodule

