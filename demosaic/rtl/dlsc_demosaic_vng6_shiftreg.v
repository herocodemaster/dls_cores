
module dlsc_demosaic_vng6_shiftreg #(
    parameter           DATA    = 8,
    parameter [47:0]    INDEX   = {48{1'b0}}
) (
    input   wire                clk,
    input   wire                clk_en,

    input   wire    [3:0]       st,

    input   wire                push,
    input   wire    [DATA-1:0]  in,

    output  wire    [DATA-1:0]  out
);

`include "dlsc_synthesis.vh"


// index ROM

wire [3:0] index;

dlsc_demosaic_vng6_rom #(
    .DATA       ( 4 ),
    .ROM        ( INDEX )
) dlsc_demosaic_vng6_rom_inst (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .out        ( index )
);


// shift register

wire [DATA-1:0] sr;

dlsc_shiftreg #(
    .DATA       ( DATA ),
    .ADDR       ( 4 ),
    .DEPTH      ( 16 )
) dlsc_shiftreg_inst (
    .clk        ( clk ),
    .write_en   ( clk_en && push ),
    .write_data ( in ),
    .read_addr  ( index ),
    .read_data  ( sr )
);


// register output
`DLSC_NO_SHREG reg [DATA-1:0] sr_reg;

always @(posedge clk) if(clk_en) begin
    sr_reg  <= sr;
end

assign out = sr_reg;


endmodule

