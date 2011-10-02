
module dlsc_address_decoder #(
    parameter ADDR      = 32,
    parameter RANGES    = 1,
    parameter [(RANGES*ADDR)-1:0] MASKS = {(RANGES*ADDR){1'b0}},    // selects address bits that don't have to match BASES
    parameter [(RANGES*ADDR)-1:0] BASES = {(RANGES*ADDR){1'b0}}
) (
    input   wire    [ADDR-1:0]      addr,
    output  wire    [RANGES-1:0]    match
);

// check for any match_pre
wire [RANGES-1:0] match_pre;

genvar j;
generate
    for(j=0;j<RANGES;j=j+1) begin:GEN_MATCHES
        assign match_pre[j] = ( (addr & ~MASKS[ (j*ADDR) +: ADDR ]) == (BASES[ (j*ADDR) +: ADDR ] & ~MASKS[ (j*ADDR) +: ADDR ]) );
    end
endgenerate

// find highest priority
assign match = match_pre & ~(match_pre - 1);

endmodule

