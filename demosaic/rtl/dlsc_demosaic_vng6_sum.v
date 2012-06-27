
module dlsc_demosaic_vng6_sum #(
    parameter DATA = 8
) (
    input   wire                clk,
    input   wire                clk_en,

    input   wire    [3:0]       st,

    // from _axes
    input   wire                axes_red_push,
    input   wire    [DATA  :0]  axes_red,
    input   wire                axes_green_push,
    input   wire    [DATA  :0]  axes_green,
    input   wire                axes_blue_push,
    input   wire    [DATA  :0]  axes_blue,
    
    // from _diag
    input   wire                diag_red_push,
    input   wire    [DATA  :0]  diag_red,
    input   wire                diag_green_push,
    input   wire    [DATA  :0]  diag_green,
    
    // from _grad
    input   wire                grad_push,
    input   wire    [DATA+2:0]  grad_axes,
    input   wire    [DATA+2:0]  grad_diag,
    input   wire    [DATA+3:0]  thresh,

    // output
    output  reg     [DATA+3:0]  sum_red,
    output  reg     [DATA+3:0]  sum_green,
    output  reg     [DATA+3:0]  sum_blue,
    output  reg     [3:0]       sum_cnt
);


// ** control

wire sum_rst;
wire sum_en;

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd0, 1'd1, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd1, 1'd0, 1'd0, 1'd0} )
) dlsc_demosaic_vng6_rom_inst_sum_rst (
    .clk        ( clk ),
    .st         ( st ),
    .out        ( sum_rst )
);

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0} )
) dlsc_demosaic_vng6_rom_inst_sum_en (
    .clk        ( clk ),
    .st         ( st ),
    .out        ( sum_en )
);


// ** axes

wire [DATA+2:0] axes_sum_red;
wire [DATA+2:0] axes_sum_green;
wire [DATA+2:0] axes_sum_blue;
wire [2:0]      axes_sum_cnt;

dlsc_demosaic_vng6_sum_slice #(
    .DATA           ( DATA ),
    .INDEX_RED      ( {4'd0, 4'd0, 4'd12, 4'd6, 4'd4, 4'd3, 4'd0, 4'd0, 4'd9, 4'd4, 4'd9, 4'd7} ),
    .INDEX_GREEN    ( {4'd0, 4'd0, 4'd13, 4'd7, 4'd9, 4'd9, 4'd0, 4'd0, 4'd14, 4'd8, 4'd9, 4'd7} ),
    .INDEX_BLUE     ( {4'd0, 4'd0, 4'd8, 4'd4, 4'd11, 4'd9, 4'd0, 4'd0, 4'd12, 4'd2, 4'd9, 4'd6} )
) dlsc_demosaic_vng6_sum_slice_inst_axes (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .st             ( st ),
    .red_push       ( axes_red_push ),
    .red            ( axes_red ),
    .green_push     ( axes_green_push ),
    .green          ( axes_green ),
    .blue_push      ( axes_blue_push ),
    .blue           ( axes_blue ),
    .grad_push      ( grad_push ),
    .grad           ( grad_axes ),
    .thresh         ( thresh ),
    .sum_rst        ( sum_rst ),
    .sum_red        ( axes_sum_red ),
    .sum_green      ( axes_sum_green ),
    .sum_blue       ( axes_sum_blue ),
    .sum_cnt        ( axes_sum_cnt )
);


// ** diag

wire [DATA+2:0] diag_sum_red;
wire [DATA+2:0] diag_sum_green;
wire [DATA+2:0] diag_sum_blue;
wire [2:0]      diag_sum_cnt;

dlsc_demosaic_vng6_sum_slice #(
    .DATA           ( DATA ),
    .INDEX_RED      ( {4'd0, 4'd0, 4'd13, 4'd8, 4'd6, 4'd3, 4'd0, 4'd0, 4'd6, 4'd6, 4'd2, 4'd2} ),
    .INDEX_GREEN    ( {4'd0, 4'd0, 4'd9, 4'd7, 4'd5, 4'd4, 4'd0, 4'd0, 4'd7, 4'd6, 4'd4, 4'd2} ),
    .INDEX_BLUE     ( {4'd0, 4'd0, 4'd10, 4'd8, 4'd7, 4'd5, 4'd0, 4'd0, 4'd13, 4'd10, 4'd8, 4'd5} )
) dlsc_demosaic_vng6_sum_slice_inst_diag (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .st             ( st ),
    .red_push       ( diag_red_push ),
    .red            ( diag_red ),
    .green_push     ( diag_green_push ),
    .green          ( diag_green ),
    .blue_push      ( axes_blue_push ), // axes_blue same as diag_blue
    .blue           ( axes_blue ),
    .grad_push      ( grad_push ),
    .grad           ( grad_diag ),
    .thresh         ( thresh ),
    .sum_rst        ( sum_rst ),
    .sum_red        ( diag_sum_red ),
    .sum_green      ( diag_sum_green ),
    .sum_blue       ( diag_sum_blue ),
    .sum_cnt        ( diag_sum_cnt )
);


// ** final sum

always @(posedge clk) if(clk_en && sum_en) begin
    sum_red     <= {1'b0,axes_sum_red  } + {1'b0,diag_sum_red  };
    sum_green   <= {1'b0,axes_sum_green} + {1'b0,diag_sum_green};
    sum_blue    <= {1'b0,axes_sum_blue } + {1'b0,diag_sum_blue };
    sum_cnt     <= {1'b0,axes_sum_cnt  } + {1'b0,diag_sum_cnt  };
end


endmodule

