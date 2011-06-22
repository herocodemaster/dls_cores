
module dlsc_demosaic_vng6_diff #(
    parameter DATA = 8
) (
    input   wire                clk,
    input   wire                clk_en,

    input   wire    [3:0]       st,
    
    // from _sum
    input   wire    [DATA+3:0]  sum_red,
    input   wire    [DATA+3:0]  sum_green,
    input   wire    [DATA+3:0]  sum_blue,
    input   wire    [3:0]       sum_cnt,

    // output
    output  reg     [DATA  :0]  diff_norm
);

// ** control

wire [1:0]  diff_a_sel;
wire        diff_b_sel;
wire        scale_en;
wire        mult_en;

dlsc_demosaic_vng6_rom #(
    .DATA       ( 2 ),
    .ROM        ( {2'd2, 2'd2, 2'd0, 2'd0, 2'd0, 2'd2, 2'd2, 2'd2, 2'd1, 2'd1, 2'd1, 2'd2} )
) dlsc_demosaic_vng6_rom_inst_a_sel (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .out        ( diff_a_sel )
);

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd0, 1'd0, 1'd1, 1'd1, 1'd1, 1'd1, 1'd1, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0} )
) dlsc_demosaic_vng6_rom_inst_b_sel (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .out        ( diff_b_sel )
);

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd0, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0} )
) dlsc_demosaic_vng6_rom_inst_scale_en (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .out        ( scale_en )
);

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd0, 1'd1, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd1, 1'd0} )
) dlsc_demosaic_vng6_rom_inst_mult_en (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .out        ( mult_en )
);


// ** input muxing

reg  [DATA+3:0] diff_a;
reg  [DATA+3:0] diff_b;

always @(posedge clk) if(clk_en) begin

    diff_a <= {(DATA+4){1'bx}};
    case(diff_a_sel)
        0: diff_a <= sum_red;
        1: diff_a <= sum_green;
        2: diff_a <= sum_blue;
    endcase

    diff_b <= {(DATA+4){1'bx}};
    case(diff_b_sel)
        0: diff_b <= sum_red;
        1: diff_b <= sum_green;
    endcase

end


// ** difference

reg  [DATA+4:0] diff;

always @(posedge clk) if(clk_en) begin
    diff <= {1'b0,diff_a} - {1'b0,diff_b};
end


// ** scale factor

reg  [15:0]     scale;

always @(posedge clk) if(clk_en && scale_en) begin

    scale <= {16{1'bx}};

    // scale winds up in a signed multiply; so can't have msbit set here
    case(sum_cnt)
        0: scale <= 16'd0;
        1: scale <= 16'd16384;  // 1/1 (2**14)
        2: scale <= 16'd8192;   // 1/2
        3: scale <= 16'd5461;   // 1/3
        4: scale <= 16'd4096;   // 1/4
        5: scale <= 16'd3276;   // 1/5
        6: scale <= 16'd2730;   // 1/6
        7: scale <= 16'd2340;   // 1/7
        8: scale <= 16'd2048;   // 1/8
    endcase

end


// ** multiply

reg signed [DATA+4:0]   mult_a;
reg signed [15:0]       mult_b;
reg signed [DATA+20:0]  mult_out;

(* MULT_STYLE="block" *) reg signed [DATA+20:0]  mult_out0;

always @(posedge clk) if(clk_en) begin

    mult_a      <= diff;
    mult_b      <= scale;

    mult_out0   <= mult_a * mult_b;

    mult_out    <= mult_out0;

end


// ** post-divide

always @(posedge clk) if(clk_en && mult_en) begin
    diff_norm   <= mult_out[ DATA+15 : 15 ]; // divide by 2**15
end


endmodule

