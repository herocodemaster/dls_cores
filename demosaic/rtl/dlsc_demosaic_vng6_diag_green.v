
module dlsc_demosaic_vng6_diag_green #(
    parameter DATA = 8
) (
    input   wire                clk,
    input   wire                clk_en,

    input   wire    [3:0]       st,

    input   wire                px_push,
    input   wire    [DATA-1:0]  px_in,

    output  wire    [DATA-1:0]  adj_absdiff,

    output  wire                diag_green_push,
    output  reg     [DATA  :0]  diag_green
);

// ** pixel source A

wire [DATA-1:0] adj_px_a;

dlsc_demosaic_vng6_shiftreg #(
    .DATA       ( DATA ),
    .INDEX      ( {4'd6, 4'd13, 4'd0, 4'd0, 4'd6, 4'd13, 4'd9, 4'd4, 4'd9, 4'd10, 4'd15, 4'd10} )
) dlsc_demosaic_vng6_shiftreg_inst_px_a (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .push       ( px_push ),
    .in         ( px_in ),
    .out        ( adj_px_a )
);

reg  [DATA-1:0] adj_px_a_prev;

always @(posedge clk) if(clk_en) begin
    adj_px_a_prev <= adj_px_a;
end


// ** absdiff

dlsc_demosaic_vng6_absdiff #(
    .DATA       ( DATA )
) dlsc_demosaic_vng6_absdiff_inst (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .in0        ( adj_px_a ),
    .in1        ( adj_px_a_prev ),
    .out        ( adj_absdiff )
);


// ** sum

wire adj_sum_rst;

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd0, 1'd0, 1'd0, 1'd1, 1'd1, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd0} )
) dlsc_demosaic_vng6_rom_inst_sum_rst (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .out        ( adj_sum_rst )
);

reg [DATA+1:0] adj_sum;

always @(posedge clk) if(clk_en) begin
    if(adj_sum_rst) begin
        adj_sum <= 0;
    end else begin
        adj_sum <= adj_sum + {2'b0,adj_px_a};
    end
end


// ** green

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd0, 1'd1, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd1} )
) dlsc_demosaic_vng6_rom_inst_green_push (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .out        ( diag_green_push )
);

wire adj_quad = adj_sum_rst;

always @(posedge clk) if(clk_en) begin
    // normalize..  quad-component gets /2, single component gets *2
    diag_green <= adj_quad ? adj_sum[DATA+1:1] : {adj_sum[DATA-1:0],1'b0};
end


endmodule

