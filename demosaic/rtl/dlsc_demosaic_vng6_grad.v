
module dlsc_demosaic_vng6_grad #(
    parameter DATA = 8
) (
    input   wire                clk,
    input   wire                clk_en,

    input   wire    [3:0]       st,
    
    // from _axes module
    input   wire                axes_h_push,
    input   wire                axes_v_push,
    input   wire    [DATA-1:0]  axes_hv,

    // from _diag module
    input   wire                diag_ne_push,
    input   wire    [DATA-1:0]  diag_ne,
    input   wire                diag_se_push,
    input   wire    [DATA-1:0]  diag_se,

    // gradient outputs
    output  wire                grad_push,
    output  reg     [DATA+2:0]  grad_axes,
    output  reg     [DATA+2:0]  grad_diag,

    output  reg     [DATA+3:0]  thresh          // min(grad) + max(grad)/2
);


// ** axes grads

wire [DATA+2:0] grad_w;
wire [DATA+2:0] grad_e;
wire [DATA+2:0] grad_n;
wire [DATA+2:0] grad_s;

dlsc_demosaic_vng6_grad_slice #(
    .DATA           ( DATA ),
    .INDEX          ( {4'd6, 4'd6, 4'd5, 4'd5, 4'd4, 4'd7, 4'd7, 4'd6, 4'd6, 4'd5, 4'd4, 4'd6} ),
    .CLEAR          ( {1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0} ),
    .MULT2          ( {1'd1, 1'd0, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd1, 1'd0, 1'd1, 1'd0, 1'd0} )
) dlsc_demosaic_vng6_grad_slice_inst_w (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .st             ( st ),
    .absdiff_push   ( axes_h_push ),
    .absdiff_in     ( axes_hv ),
    .grad_out       ( grad_w )
);

dlsc_demosaic_vng6_grad_slice #(
    .DATA           ( DATA ),
    .INDEX          ( {4'd4, 4'd4, 4'd3, 4'd3, 4'd2, 4'd2, 4'd5, 4'd4, 4'd4, 4'd3, 4'd2, 4'd1} ),
    .CLEAR          ( {1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0} ),
    .MULT2          ( {1'd0, 1'd0, 1'd1, 1'd0, 1'd1, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd1} )
) dlsc_demosaic_vng6_grad_slice_inst_e (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .st             ( st ),
    .absdiff_push   ( axes_h_push ),
    .absdiff_in     ( axes_hv ),
    .grad_out       ( grad_e )
);

dlsc_demosaic_vng6_grad_slice #(
    .DATA           ( DATA ),
    .INDEX          ( {4'd1, 4'd5, 4'd5, 4'd3, 4'd3, 4'd1, 4'd0, 4'd5, 4'd4, 4'd3, 4'd3, 4'd2} ),
    .CLEAR          ( {1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0} ),
    .MULT2          ( {1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd1} )
) dlsc_demosaic_vng6_grad_slice_inst_n (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .st             ( st ),
    .absdiff_push   ( axes_v_push ),
    .absdiff_in     ( axes_hv ),
    .grad_out       ( grad_n )
);

dlsc_demosaic_vng6_grad_slice #(
    .DATA           ( DATA ),
    .INDEX          ( {4'd2, 4'd0, 4'd5, 4'd4, 4'd4, 4'd2, 4'd0, 4'd0, 4'd5, 4'd4, 4'd3, 4'd3} ),
    .CLEAR          ( {1'd0, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0} ),
    .MULT2          ( {1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1} )
) dlsc_demosaic_vng6_grad_slice_inst_s (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .st             ( st ),
    .absdiff_push   ( axes_v_push ),
    .absdiff_in     ( axes_hv ),
    .grad_out       ( grad_s )
);


// ** diag grads

wire [DATA+2:0] grad_nw;
wire [DATA+2:0] grad_sw;
wire [DATA+2:0] grad_ne;
wire [DATA+2:0] grad_se;

dlsc_demosaic_vng6_grad_slice #(
    .DATA           ( DATA ),
    .INDEX          ( {4'd12, 4'd11, 4'd7, 4'd7, 4'd5, 4'd0, 4'd0, 4'd14, 4'd12, 4'd10, 4'd9, 4'd12} ),
    .CLEAR          ( {1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd1, 1'd1, 1'd0, 1'd0, 1'd0} ),
    .MULT2          ( {1'd1, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd1, 1'd1, 1'd1} )
) dlsc_demosaic_vng6_grad_slice_inst_nw (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .st             ( st ),
    .absdiff_push   ( diag_se_push ),
    .absdiff_in     ( diag_se ),
    .grad_out       ( grad_nw )
);

dlsc_demosaic_vng6_grad_slice #(
    .DATA           ( DATA ),
    .INDEX          ( {4'd9, 4'd9, 4'd9, 4'd8, 4'd8, 4'd2, 4'd0, 4'd0, 4'd11, 4'd10, 4'd8, 4'd7} ),
    .CLEAR          ( {1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd1, 1'd1, 1'd0, 1'd0} ),
    .MULT2          ( {1'd1, 1'd0, 1'd1, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd1, 1'd1, 1'd1} )
) dlsc_demosaic_vng6_grad_slice_inst_sw (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .st             ( st ),
    .absdiff_push   ( diag_ne_push ),
    .absdiff_in     ( diag_ne ),
    .grad_out       ( grad_sw )
);

dlsc_demosaic_vng6_grad_slice #(
    .DATA           ( DATA ),
    .INDEX          ( {4'd4, 4'd10, 4'd6, 4'd5, 4'd5, 4'd4, 4'd3, 4'd0, 4'd0, 4'd9, 4'd8, 4'd5} ),
    .CLEAR          ( {1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd1, 1'd1, 1'd0} ),
    .MULT2          ( {1'd1, 1'd1, 1'd0, 1'd1, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd1} )
) dlsc_demosaic_vng6_grad_slice_inst_ne (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .st             ( st ),
    .absdiff_push   ( diag_ne_push ),
    .absdiff_in     ( diag_ne ),
    .grad_out       ( grad_ne )
);

dlsc_demosaic_vng6_grad_slice #(
    .DATA           ( DATA ),
    .INDEX          ( {4'd6, 4'd5, 4'd7, 4'd7, 4'd5, 4'd3, 4'd2, 4'd1, 4'd0, 4'd0, 4'd9, 4'd8} ),
    .CLEAR          ( {1'd0, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd1, 1'd1} ),
    .MULT2          ( {1'd1, 1'd1, 1'd1, 1'd1, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1} )
) dlsc_demosaic_vng6_grad_slice_inst_se (
    .clk            ( clk ),
    .clk_en         ( clk_en ),
    .st             ( st ),
    .absdiff_push   ( diag_se_push ),
    .absdiff_in     ( diag_se ),
    .grad_out       ( grad_se )
);


// ** grad push

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd0, 1'd1, 1'd1, 1'd1, 1'd1, 1'd0, 1'd0, 1'd1, 1'd1, 1'd1, 1'd1, 1'd0} )
) dlsc_demosaic_vng6_rom_inst_grad_push (
    .clk        ( clk ),
    .st         ( st ),
    .out        ( grad_push )
);


// ** muxing

wire [1:0] grad_sel;

dlsc_demosaic_vng6_rom #(
    .DATA       ( 2 ),
    .ROM        ( {2'd0, 2'd1, 2'd2, 2'd3, 2'd0, 2'd0, 2'd0, 2'd1, 2'd2, 2'd3, 2'd0, 2'd0} )
) dlsc_demosaic_vng6_rom_inst_grad_sel (
    .clk        ( clk ),
    .st         ( st ),
    .out        ( grad_sel )
);

always @(posedge clk) if(clk_en) begin
    case(grad_sel)
        0: grad_axes <= grad_w;
        1: grad_axes <= grad_e;
        2: grad_axes <= grad_n;
        3: grad_axes <= grad_s;
    endcase
    case(grad_sel)
        0: grad_diag <= grad_nw;
        1: grad_diag <= grad_sw;
        2: grad_diag <= grad_ne;
        3: grad_diag <= grad_se;
    endcase
end


// ** compex between axes/diag

wire [DATA+2:0] grad_ad_min;
wire [DATA+2:0] grad_ad_max;

dlsc_demosaic_vng6_compex #(
    .DATA       ( DATA+3 ),
    .PIPELINE   ( 1 )
) dlsc_demosaic_vng6_compex_inst_ad (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .in_data0   ( grad_axes ),
    .in_data1   ( grad_diag ),
    .out_data0  ( grad_ad_min ),
    .out_data1  ( grad_ad_max )
);


// ** find overall min/max

wire grad_rst;

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd0, 1'd1, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd1, 1'd0, 1'd0, 1'd0} )
) dlsc_demosaic_vng6_rom_inst_grad_rst (
    .clk        ( clk ),
    .st         ( st ),
    .out        ( grad_rst )
);

// min

reg  [DATA+2:0] grad_min;

wire grad_min_wins = (grad_min <= grad_ad_min);

always @(posedge clk) if(clk_en) begin
    if(grad_rst) begin
        grad_min    <= {(DATA+3){1'b1}};
    end else begin
        grad_min    <= grad_min_wins ? grad_min : grad_ad_min;
    end
end


// max

reg  [DATA+2:0] grad_max;

wire grad_max_wins = (grad_max >= grad_ad_max);

always @(posedge clk) if(clk_en) begin
    if(grad_rst) begin
        grad_max    <= {(DATA+3){1'b0}};
    end else begin
        grad_max    <= grad_max_wins ? grad_max : grad_ad_max;
    end
end


// ** compute thresh

wire thresh_en;

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0} )
) dlsc_demosaic_vng6_rom_inst_thresh_en (
    .clk        ( clk ),
    .st         ( st ),
    .out        ( thresh_en )
);

always @(posedge clk) if(clk_en && thresh_en) begin
    thresh <= {1'b0,grad_min} + {2'b00,grad_max[DATA+2:1]};
end


endmodule

