
module dlsc_demosaic_vng6_out #(
    parameter DATA = 8
) (
    input   wire                clk,
    input   wire                clk_en,
    input   wire                rst,

    input   wire    [3:0]       st,

    input   wire                px_push,
    input   wire                px_masked,
    input   wire                px_last,
    input   wire                px_row_red,     // current row has red pixels (otherwise blue)
    input   wire    [DATA-1:0]  px_in,

    // from _diff
    input   wire    [DATA  :0]  diff_norm,

    // output
    output  reg                 out_valid,
    output  reg                 out_last,
    output  reg     [DATA-1:0]  out_red,
    output  reg     [DATA-1:0]  out_green,
    output  reg     [DATA-1:0]  out_blue
);

// ** control

wire center_en;
wire redgreen_en;
wire blue_en;
wire redgreen_sel;

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0} )
) dlsc_demosaic_vng6_rom_inst_center_en (
    .clk        ( clk ),
    .st         ( st ),
    .out        ( center_en )
);

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd0} )
) dlsc_demosaic_vng6_rom_inst_redgreen_en (
    .clk        ( clk ),
    .st         ( st ),
    .out        ( redgreen_en )
);

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0} )
) dlsc_demosaic_vng6_rom_inst_blue_en (
    .clk        ( clk ),
    .st         ( st ),
    .out        ( blue_en )
);

dlsc_demosaic_vng6_rom #(
    .DATA       ( 1 ),
    .ROM        ( {1'd1, 1'd1, 1'd1, 1'd1, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd0, 1'd1, 1'd1} )
) dlsc_demosaic_vng6_rom_inst_redgreen_sel (
    .clk        ( clk ),
    .st         ( st ),
    .out        ( redgreen_sel )
);


// ** center pixel buffer

wire [DATA-1:0] px_a;
wire            px_a_masked;
wire            px_a_last;
wire            px_a_row_red;

dlsc_demosaic_vng6_shiftreg #(
    .DATA       ( DATA+3 ),
    .INDEX      ( {4'd8, 4'd7, 4'd7, 4'd8, 4'd8, 4'd8, 4'd8, 4'd7, 4'd7, 4'd8, 4'd8, 4'd8} )
) dlsc_demosaic_vng6_shiftreg_inst_px_a (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .push       ( px_push && center_en ),
    .in         ( {px_row_red,  px_last,  px_masked,  px_in} ),
    .out        ( {px_a_row_red,px_a_last,px_a_masked,px_a } )
);

// count entries in buffer, so we know once it has been primed
// first possible completely valid output is once there are >= 11 entries

reg         primed;
reg  [3:0]  px_cnt;

always @(posedge clk) begin
    if(rst) begin
        primed      <= 1'b0;
        px_cnt      <= 0;
    end else if(clk_en && px_push && center_en && !primed) begin
        primed      <= (px_cnt == 10);
        px_cnt      <= px_cnt + 1;
    end
end


// ** compute final result

reg [DATA+1:0] res;

always @(posedge clk) if(clk_en) begin
    // zero extend unsigned px_a, sign-extend diff_norm
    res <= {2'b00,px_a} + {diff_norm[DATA],diff_norm};
end

// saturate

reg [DATA-1:0] res_sat;

always @(posedge clk) if(clk_en) begin
    if(res[DATA+1])     // sign bit indicates negative; clamp to 0
        res_sat <= 0;
    else if(res[DATA])  // MSbit (after sign) indicates overflow; clamp to max
        res_sat <= {DATA{1'b1}};
    else
        res_sat <= res[DATA-1:0];
end


// ** drive outputs

always @(posedge clk) if(clk_en) begin
    // red/green
    if(redgreen_en) begin
        out_green   <= !redgreen_sel ? res_sat : px_a;
        if(px_a_row_red) begin
            out_red     <=  redgreen_sel ? res_sat : px_a;
        end else begin
            // swap red/blue
            out_blue    <=  redgreen_sel ? res_sat : px_a;
        end
    end
    // blue
    if(blue_en) begin
        if(px_a_row_red) begin
            out_blue    <= res_sat;
        end else begin
            // swap red/blue
            out_red     <= res_sat;
        end
    end
end

// valid
always @(posedge clk) begin
    out_valid   <= 1'b0; // always clear after 1 cycle
    out_last    <= 1'b0;
    if(clk_en && blue_en && primed && !px_a_masked) begin
        // set valid when blue is driven
        out_valid   <= 1'b1;
        out_last    <= px_a_last;
    end
end

endmodule

