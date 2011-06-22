
module dlsc_demosaic_vng6_sum_slice #(
    parameter        DATA        = 8,
    parameter [47:0] INDEX_RED   = 0,
    parameter [47:0] INDEX_GREEN = 0,
    parameter [47:0] INDEX_BLUE  = 0
) (
    input   wire                clk,
    input   wire                clk_en,

    input   wire    [3:0]       st,

    input   wire                red_push,
    input   wire    [DATA  :0]  red,
    input   wire                green_push,
    input   wire    [DATA  :0]  green,
    input   wire                blue_push,
    input   wire    [DATA  :0]  blue,

    input   wire                grad_push,
    input   wire    [DATA+2:0]  grad,

    input   wire    [DATA+3:0]  thresh,

    input   wire                sum_rst,
    
    output  wire    [DATA+2:0]  sum_red,
    output  wire    [DATA+2:0]  sum_green,
    output  wire    [DATA+2:0]  sum_blue,
    output  reg     [2:0]       sum_cnt
);

// ** grad buffer

wire [DATA+2:0] grad_a;

dlsc_demosaic_vng6_shiftreg #(
    .DATA       ( DATA+3 ),
    .INDEX      ( {12{4'd3}} )  // all are 3 in current scheme..
) dlsc_demosaic_vng6_shiftreg_inst_px_a (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .push       ( grad_push ),
    .in         ( grad ),
    .out        ( grad_a )
);


// ** thresh check

reg grad_comp;

always @(posedge clk) if(clk_en) begin
    grad_comp <= ({1'b0,grad_a} < thresh);
end


// ** count

always @(posedge clk) if(clk_en) begin
    if(sum_rst) begin
        sum_cnt     <= 0;
    end else begin
        if(grad_comp) begin
            sum_cnt     <= sum_cnt + 1;
        end
    end
end


// ** red

dlsc_demosaic_vng6_sum_slice_comp #(
    .DATA       ( DATA ),
    .INDEX      ( INDEX_RED )
) dlsc_demosaic_vng6_sum_slice_comp_inst_red (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .px_push    ( red_push ),
    .px         ( red ),
    .sum_rst    ( sum_rst ),
    .grad_comp  ( grad_comp ),
    .sum        ( sum_red )
);


// ** green

dlsc_demosaic_vng6_sum_slice_comp #(
    .DATA       ( DATA ),
    .INDEX      ( INDEX_GREEN )
) dlsc_demosaic_vng6_sum_slice_comp_inst_green (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .px_push    ( green_push ),
    .px         ( green ),
    .sum_rst    ( sum_rst ),
    .grad_comp  ( grad_comp ),
    .sum        ( sum_green )
);


// ** blue

dlsc_demosaic_vng6_sum_slice_comp #(
    .DATA       ( DATA ),
    .INDEX      ( INDEX_BLUE )
) dlsc_demosaic_vng6_sum_slice_comp_inst_blue (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .px_push    ( blue_push ),
    .px         ( blue ),
    .sum_rst    ( sum_rst ),
    .grad_comp  ( grad_comp ),
    .sum        ( sum_blue )
);

endmodule

