
module dlsc_demosaic_vng6_diag #(
    parameter DATA = 8
) (
    input   wire                clk,
    input   wire                clk_en,

    input   wire    [3:0]       st,

    input   wire                px_push,
    input   wire    [DATA-1:0]  px_in,
    
    output  reg     [DATA  :0]  axes_red_diag,      // to _axes module
    input   wire    [DATA  :0]  axes_add,           // from _axes module

    output  wire                diag_ne_push,
    output  reg     [DATA-1:0]  diag_ne,

    output  wire                diag_se_push,
    output  reg     [DATA-1:0]  diag_se,

    output  wire                diag_red_push,
    output  wire    [DATA  :0]  diag_red,

    output  wire                diag_green_push,
    output  wire    [DATA  :0]  diag_green

    // blue supplied by _axes_pre module
);

// ** pixel source A

wire [DATA-1:0] diag_px_a;

dlsc_demosaic_vng6_shiftreg #(
    .DATA       ( DATA ),
    .INDEX      ( {4'd13, 4'd4, 4'd14, 4'd5, 4'd13, 4'd4, 4'd13, 4'd4, 4'd2, 4'd13, 4'd13, 4'd4} )
) dlsc_demosaic_vng6_shiftreg_inst_px_a (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .push       ( px_push ),
    .in         ( px_in ),
    .out        ( diag_px_a )
);

reg  [DATA-1:0] diag_px_a_prev;

always @(posedge clk) if(clk_en) begin
    diag_px_a_prev <= diag_px_a;
end


// ** pixel source B

wire [DATA-1:0] diag_px_b;

dlsc_demosaic_vng6_shiftreg #(
    .DATA       ( DATA ),
    .INDEX      ( {4'd1, 4'd12, 4'd2, 4'd13, 4'd1, 4'd12, 4'd1, 4'd12, 4'd14, 4'd5, 4'd1, 4'd12} )
) dlsc_demosaic_vng6_shiftreg_inst_px_b (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .push       ( px_push ),
    .in         ( px_in ),
    .out        ( diag_px_b )
);


// ** red_diag add

always @(posedge clk) if(clk_en) begin
    axes_red_diag <= {1'b0,diag_px_a} + {1'b0,diag_px_a_prev};
end


// ** absdiff

wire [DATA-1:0] diag_absdiff;

dlsc_demosaic_vng6_absdiff #(
    .DATA       ( DATA )
) dlsc_demosaic_vng6_absdiff_inst (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .in0        ( diag_px_a ),
    .in1        ( diag_px_b ),
    .out        ( diag_absdiff )
);


// ** add

reg [DATA:0] diag_add;

always @(posedge clk) if(clk_en) begin
    diag_add    <= {1'b0,diag_px_a} + {1'b0,diag_px_b};
end


// ** red

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd1, 1'd1, 1'd1, 1'd1} )
) dlsc_demosaic_vng6_rom_inst_red_push (
    .clk        ( clk ),
    .st         ( st ),
    .out        ( diag_red_push )
);

wire diag_red_sel;

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd1, 1'd0, 1'd0} )
) dlsc_demosaic_vng6_rom_inst_red_sel (
    .clk        ( clk ),
    .st         ( st ),
    .out        ( diag_red_sel )
);

reg [DATA:0] diag_red_pre;

always @(posedge clk) if(clk_en) begin
    diag_red_pre <= diag_red_sel ? axes_add : diag_add;
end

// need to delay red by 4 more (otherwise 16 entry shift-registers aren't
// enough downstream)

dlsc_pipedelay_clken #(
    .DATA       ( DATA+1 ),
    .DELAY      ( 4 )
) dlsc_pipedelay_clken_inst_diag_red (
    .clk        ( clk ),
    .clk_en     ( clk_en && diag_red_push ),
    .in_data    ( diag_red_pre ),
    .out_data   ( diag_red )
);


// ** green

wire [DATA-1:0] adj_absdiff;

dlsc_demosaic_vng6_diag_green #(
    .DATA               ( DATA )
) dlsc_demosaic_vng6_diag_green_inst (
    .clk                ( clk ),
    .clk_en             ( clk_en ),
    .st                 ( st ),
    .px_push            ( px_push ),
    .px_in              ( px_in ),
    .adj_absdiff        ( adj_absdiff ),
    .diag_green_push    ( diag_green_push ),
    .diag_green         ( diag_green )
);


// ** ne

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd1, 1'd1, 1'd1, 1'd1, 1'd1, 1'd1, 1'd0, 1'd1, 1'd0, 1'd1, 1'd1, 1'd1} )
) dlsc_demosaic_vng6_rom_inst_ne_push (
    .clk        ( clk ),
    .st         ( st ),
    .out        ( diag_ne_push )
);

wire diag_ne_sel;

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd0, 1'd1, 1'd0, 1'd1, 1'd0, 1'd1, 1'd0, 1'd1, 1'd0, 1'd1, 1'd0, 1'd1} )
) dlsc_demosaic_vng6_rom_inst_ne_sel (
    .clk        ( clk ),
    .st         ( st ),
    .out        ( diag_ne_sel )
);

always @(posedge clk) if(clk_en) begin
    diag_ne <= diag_ne_sel ? adj_absdiff : diag_absdiff;
end


// ** se

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd1, 1'd0, 1'd1, 1'd1, 1'd1, 1'd1, 1'd1, 1'd0, 1'd1, 1'd1, 1'd1, 1'd1} )
) dlsc_demosaic_vng6_rom_inst_se_push (
    .clk        ( clk ),
    .st         ( st ),
    .out        ( diag_se_push )
);

wire diag_se_sel = !diag_ne_sel;

always @(posedge clk) if(clk_en) begin
    diag_se <= diag_se_sel ? adj_absdiff : diag_absdiff;
end

endmodule

