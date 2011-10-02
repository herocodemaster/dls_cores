
module dlsc_address_decoder #(
    parameter ADDR      = 32,
    parameter RANGES    = 1,
    parameter RANGESB   = 1,
    parameter [(RANGES*ADDR)-1:0] MASKS = {(RANGES*ADDR){1'b0}},    // selects address bits that don't have to match BASES
    parameter [(RANGES*ADDR)-1:0] BASES = {(RANGES*ADDR){1'b0}}
) (
    input   wire    [ADDR-1:0]      addr,
    output  reg                     match_valid,
    output  reg     [RANGES-1:0]    match_onehot,
    output  reg     [RANGESB-1:0]   match
);

integer i;

always @* begin
    match_valid     = 1'b0;
    match_onehot    = {RANGES{1'bx}};
    match           = {RANGESB{1'bx}};

    for(i=RANGES;i>=0;i=i-1) begin
        if( (addr & ~MASKS[ (i*ADDR) +: ADDR ]) == (BASES[ (i*ADDR) +: ADDR ] & ~MASKS[ (i*ADDR) +: ADDR ]) ) begin
/* verilator lint_off WIDTH */
            match_valid     = 1'b1;
            match_onehot    = (1<<i);
            match           = i;
/* verilator lint_on WIDTH */
        end
    end
end

endmodule

