
module dlsc_demosaic_vng6_axes #(
    parameter DATA = 8
) (
    input   wire                clk,
    input   wire                clk_en,

    input   wire    [3:0]       st,

    input   wire                px_push,
    input   wire    [DATA-1:0]  px_in,

    input   wire    [DATA  :0]  axes_red_diag,      // from _diag module
    output  reg     [DATA  :0]  axes_add,           // to _diag module

    output  wire                axes_h_push,
    output  wire                axes_v_push,
    output  wire    [DATA-1:0]  axes_hv,

    output  wire                axes_red_push,
    output  wire    [DATA  :0]  axes_red,

    output  wire                axes_green_push,
    output  reg     [DATA  :0]  axes_green,

    output  wire                axes_blue_push,
    output  reg     [DATA  :0]  axes_blue
);

// ** pixel source A

wire [DATA-1:0] axes_px_a;

dlsc_demosaic_vng6_shiftreg #(
    .DATA       ( DATA ),
    .INDEX      ( {4'd13, 4'd13, 4'd13, 4'd15, 4'd11, 4'd13, 4'd14, 4'd13, 4'd5, 4'd14, 4'd11, 4'd13} )
) dlsc_demosaic_vng6_shiftreg_inst_px_a (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .push       ( px_push ),
    .in         ( px_in ),
    .out        ( axes_px_a )
);


// ** pixel source B

wire [DATA-1:0] axes_px_b;

dlsc_demosaic_vng6_shiftreg #(
    .DATA       ( DATA ),
    .INDEX      ( {4'd11, 4'd3, 4'd3, 4'd13, 4'd1, 4'd11, 4'd12, 4'd11, 4'd15, 4'd4, 4'd13, 4'd3} )
) dlsc_demosaic_vng6_shiftreg_inst_px_b (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .push       ( px_push ),
    .in         ( px_in ),
    .out        ( axes_px_b )
);


// ** h/v_push

assign axes_v_push = !axes_h_push;

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd1, 1'd0, 1'd1, 1'd0, 1'd1, 1'd1, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd1} )
) dlsc_demosaic_vng6_rom_inst_h_push (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .out        ( axes_h_push )
);


// ** absdiff

dlsc_demosaic_vng6_absdiff #(
    .DATA       ( DATA )
) dlsc_demosaic_vng6_absdiff_inst (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .in0        ( axes_px_a ),
    .in1        ( axes_px_b ),
    .out        ( axes_hv )
);


// ** add

always @(posedge clk) if(clk_en) begin
    axes_add    <= {1'b0,axes_px_a} + {1'b0,axes_px_b};
end


// ** red

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd1, 1'd1, 1'd1, 1'd1, 1'd0} )
) dlsc_demosaic_vng6_rom_inst_red_push (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .out        ( axes_red_push )
);

wire [1:0] axes_red_sel;

dlsc_demosaic_vng6_rom #(
    .DATA       ( 2 ),
    .ROM        ( {2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd2, 2'd1, 2'd1, 2'd0, 2'd2} )
) dlsc_demosaic_vng6_rom_inst_red_sel (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .out        ( axes_red_sel )
);

reg [DATA:0] axes_red_pre;

always @(posedge clk) if(clk_en) begin
    axes_red_pre <= {(DATA+1){1'bx}};

    case(axes_red_sel)
        0: axes_red_pre <= {axes_px_a,1'b0};
        1: axes_red_pre <= axes_add;
        2: axes_red_pre <= axes_red_diag;
    endcase
end

// need to delay red by 4 more (otherwise 16 entry shift-registers aren't
// enough downstream)

dlsc_pipedelay_clken #(
    .DATA       ( DATA+1 ),
    .DELAY      ( 4 )
) dlsc_pipedelay_clken_inst_axes_red (
    .clk        ( clk ),
    .clk_en     ( clk_en && axes_red_push ),
    .in_data    ( axes_red_pre ),
    .out_data   ( axes_red )
);


// ** green

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd1, 1'd1, 1'd0, 1'd0, 1'd1, 1'd0, 1'd1, 1'd1, 1'd0, 1'd0, 1'd0, 1'd1} )
) dlsc_demosaic_vng6_rom_inst_green_push (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .out        ( axes_green_push )
);

wire axes_green_sel;

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd1, 1'd0, 1'd0, 1'd1, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0} )
) dlsc_demosaic_vng6_rom_inst_green_sel (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .out        ( axes_green_sel )
);

always @(posedge clk) if(clk_en) begin
    axes_green <= axes_green_sel ? axes_add : {axes_px_a,1'b0};
end


// ** blue

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd0, 1'd1, 1'd1, 1'd1, 1'd1, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0} )
) dlsc_demosaic_vng6_rom_inst_blue_push (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .out        ( axes_blue_push )
);

wire axes_blue_sel;

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd0, 1'd1, 1'd1, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0} )
) dlsc_demosaic_vng6_rom_inst_blue_sel (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .out        ( axes_blue_sel )
);

always @(posedge clk) if(clk_en) begin
    axes_blue <= axes_blue_sel ? axes_add : {axes_px_a,1'b0};
end


endmodule

