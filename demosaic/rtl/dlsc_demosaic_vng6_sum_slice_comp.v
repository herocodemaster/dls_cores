
module dlsc_demosaic_vng6_sum_slice_comp #(
    parameter        DATA  = 8,
    parameter [47:0] INDEX = 0
) (
    input   wire                clk,
    input   wire                clk_en,

    input   wire    [3:0]       st,

    input   wire                px_push,
    input   wire    [DATA  :0]  px,

    input   wire                sum_rst,

    input   wire                grad_comp,

    output  reg     [DATA+2:0]  sum
);

// ** pixel buffer

wire [DATA  :0] px_a;

dlsc_demosaic_vng6_shiftreg #(
    .DATA       ( DATA+1 ),
    .INDEX      ( INDEX )
) dlsc_demosaic_vng6_shiftreg_inst_px_a (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .st         ( st ),
    .push       ( px_push ),
    .in         ( px ),
    .out        ( px_a )
);


// ** sum

always @(posedge clk) if(clk_en) begin
    if(sum_rst) begin
        sum     <= 0;
    end else begin
        if(grad_comp) begin
            sum     <= sum + {2'b00,px_a};
        end
    end
end


endmodule

