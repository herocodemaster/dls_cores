
module dlsc_demosaic_vng6_grad_slice #(
    parameter        DATA  = 8,
    parameter [47:0] INDEX = 0,
    parameter [11:0] CLEAR = 0,
    parameter [11:0] MULT2 = 0
) (
    input   wire                clk,
    input   wire                clk_en,

    input   wire    [3:0]       st,

    input   wire                absdiff_push,
    input   wire    [DATA-1:0]  absdiff_in,

    output  reg     [DATA+2:0]  grad_out
);

// ** absdiff source

wire [DATA-1:0] absdiff;

dlsc_demosaic_vng6_shiftreg #(
    .DATA       ( DATA ),
    .INDEX      ( INDEX )
) dlsc_demosaic_vng6_shiftreg_inst (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .push       ( absdiff_push ),
    .in         ( absdiff_in ),
    .out        ( absdiff )
);


// ** clear

wire grad_clr;

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( CLEAR )
) dlsc_demosaic_vng6_rom_inst_grad_clr (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .out        ( grad_clr )
);


// ** multiply-by-2

wire grad_mult2;

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( MULT2 )
) dlsc_demosaic_vng6_rom_inst_grad_mult2 (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .out        ( grad_mult2 )
);


// ** grad output

always @(posedge clk) if(clk_en) begin
    grad_out <= (grad_clr ? 0 : grad_out) + (grad_mult2 ? {2'b00,absdiff,1'b0} : {3'b000,absdiff});
end


endmodule

